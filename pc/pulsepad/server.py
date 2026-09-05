"""PulsePad server: accepts phone connections over UDP (Wi-Fi) and TCP (USB).

Design notes
------------
* The daemon listens on BOTH a UDP socket (for low-latency Wi-Fi streaming and
  auto-discovery broadcast responses) and a TCP socket (for USB mode, which goes
  through ``adb forward tcp:5005 tcp:5005`` and presents as localhost:5005).

* UDP is connectionless.  Any datagram received is a full controller snapshot
  (see :mod:`pulsepad.protocol`), so no connection bookkeeping is required for
  input -- this is what keeps Wi-Fi latency at a minimum and makes the link
  tolerant of packet loss.

* TCP is used for USB mode and as a reliable control channel.  A TCP client is
  the "remote" that can receive HAPTIC commands.  If it drops, we simply wait
  for the next one (auto-reconnect on the phone side).

* Auto-discovery: the phone broadcasts a HELLO datagram to the subnet on the
  discovery port; the daemon replies with a small beacon so the phone can find
  the PC without typing an IP address.
"""

import select
import socket
import struct
import threading
import time

from . import protocol as P
from .virtual_device import VirtualGamepad

DISCOVERY_ADDR = "255.255.255.255"
DISCOVERY_PORT = 54321
UDP_PORT = 5006
TCP_PORT = 5005

# Beacon sent by the server in response to HELLO (offers the ports to use).
#   b"PPB1" + <udp_port u16> + <tcp_port u16> + <server name ascii>
BEACON_MAGIC = b"PPB1"


def make_beacon(name="PulsePad", udp_port=UDP_PORT, tcp_port=TCP_PORT) -> bytes:
    name_bytes = name.encode("ascii", "replace")[:24]
    return (BEACON_MAGIC
            + struct.pack(">HH", udp_port, tcp_port)
            + bytes([len(name_bytes)]) + name_bytes)


def parse_beacon(data: bytes):
    """Return (udp_port, tcp_port, name) or None if not a valid beacon."""
    if len(data) < 8 or data[:4] != BEACON_MAGIC:
        return None
    udp_port, tcp_port = struct.unpack(">HH", data[4:8])
    n = data[8]
    name = data[9:9 + n].decode("ascii", "replace")
    return udp_port, tcp_port, name


class PulsePadServer:
    # A Wi-Fi peer is considered connected while we see data within this window.
    _UDP_PEER_TIMEOUT = 3.0

    def __init__(self, gamepad: VirtualGamepad,
                 tcp_port=TCP_PORT, udp_port=UDP_PORT,
                 discovery_port=DISCOVERY_PORT,
                 on_haptic=None,
                 on_state=None,
                 on_key=None,
                 name="PulsePad"):
        self.gamepad = gamepad
        self.tcp_port = tcp_port
        self.udp_port = udp_port
        self.discovery_port = discovery_port
        self.name = name

        self._on_haptic = on_haptic
        self._on_state = on_state
        self._on_key = on_key

        self.running = False
        self._tcp_sock = None
        self._udp_sock = None
        self._disc_sock = None
        self._tcp_thread = None
        self._udp_thread = None
        self._disc_thread = None

        # Latency measured over the most recent PING/PONG round trip (ms).
        self.latency_ms = 0
        self._latency_seq = 0

        self._tcp_clients = []
        self._tcp_lock = threading.Lock()

        # Active UDP peers (Wi-Fi phones): addr -> last-seen (epoch seconds).
        # UDP is connectionless, so a peer counts as "connected" while it keeps
        # sending us data; stale peers are pruned after a few seconds.
        self._udp_peers = {}
        self._udp_peers_lock = threading.Lock()

    # ------------------------------------------------------------------ #
    def start(self):
        self.running = True

        # TCP (USB mode). localhost thanks to adb forward.
        self._tcp_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._tcp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._tcp_sock.bind(("0.0.0.0", self.tcp_port))
        self._tcp_sock.listen(4)
        self._tcp_sock.settimeout(0.5)

        # UDP (Wi-Fi streaming + discovery response).
        self._udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._udp_sock.bind(("0.0.0.0", self.udp_port))
        self._udp_sock.settimeout(0.5)

        # Discovery listener.
        self._disc_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._disc_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            self._disc_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        except OSError:
            pass
        self._disc_sock.bind(("0.0.0.0", self.discovery_port))
        self._disc_sock.settimeout(0.5)

        self._tcp_thread = threading.Thread(target=self._tcp_loop, daemon=True)
        self._udp_thread = threading.Thread(target=self._udp_loop, daemon=True)
        self._disc_thread = threading.Thread(target=self._disc_loop, daemon=True)
        self._tcp_thread.start()
        self._udp_thread.start()
        self._disc_thread.start()

        print(f"[server] listening TCP   0.0.0.0:{self.tcp_port} (USB/adb forward)")
        print(f"[server] listening UDP   0.0.0.0:{self.udp_port} (Wi-Fi streaming)")
        print(f"[server] discovery UDP   0.0.0.0:{self.discovery_port} (auto-find)")

    def stop(self):
        self.running = False
        for s in (self._tcp_sock, self._udp_sock, self._disc_sock):
            if s:
                try:
                    s.close()
                except OSError:
                    pass
        with self._tcp_lock:
            for c in self._tcp_clients:
                try:
                    c.close()
                except OSError:
                    pass
            self._tcp_clients.clear()
        with self._udp_peers_lock:
            self._udp_peers.clear()
        # Wait for the listener threads to wake (closed sockets -> OSError, or
        # the 0.5s recv/accept timeout) and exit, so the ports are actually
        # released before stop() returns. Otherwise an immediate restart fails
        # with "Address already in use".
        for t in (self._tcp_thread, self._udp_thread, self._disc_thread):
            if t:
                t.join(timeout=1.0)

    @property
    def client_count(self) -> int:
        """Number of phones actively connected (TCP + recent UDP peers)."""
        with self._tcp_lock:
            tcp = len(self._tcp_clients)
        with self._udp_peers_lock:
            now = time.time()
            stale = [a for a, t in self._udp_peers.items()
                     if now - t > self._UDP_PEER_TIMEOUT]
            for a in stale:
                del self._udp_peers[a]
            udp = len(self._udp_peers)
        return tcp + udp

    @property
    def transport_counts(self):
        """(tcp, udp) client counts, useful for status display."""
        with self._tcp_lock:
            tcp = len(self._tcp_clients)
        with self._udp_peers_lock:
            now = time.time()
            stale = [a for a, t in self._udp_peers.items()
                     if now - t > self._UDP_PEER_TIMEOUT]
            for a in stale:
                del self._udp_peers[a]
            udp = len(self._udp_peers)
        return tcp, udp

    @property
    def on_state(self):
        return self._on_state

    @on_state.setter
    def on_state(self, cb):
        self._on_state = cb

    @property
    def on_key(self):
        return self._on_key

    @on_key.setter
    def on_key(self, cb):
        self._on_key = cb

    # ------------------------------------------------------------------ #
    # UDP: pure streaming. Every datagram is a full controller snapshot.
    def _udp_loop(self):
        while self.running:
            try:
                data, addr = self._udp_sock.recvfrom(2048)
            except socket.timeout:
                continue
            except OSError:
                break
            if not data:
                continue
            with self._udp_peers_lock:
                self._udp_peers[addr] = time.time()
            self._handle_datagram(data, addr, reliable=False, via_udp=True)

    # TCP: reliable control channel (also accepts full-state packets).
    def _tcp_loop(self):
        while self.running:
            try:
                conn, addr = self._tcp_sock.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            with self._tcp_lock:
                self._tcp_clients.append(conn)
            print(f"[tcp] client connected: {addr}")
            t = threading.Thread(target=self._tcp_client_loop,
                                 args=(conn, addr), daemon=True)
            t.start()

    def _tcp_client_loop(self, conn, addr):
        buf = bytearray()
        conn.settimeout(0.5)
        while self.running:
            try:
                chunk = conn.recv(4096)
            except socket.timeout:
                continue
            except OSError:
                break
            if not chunk:
                break
            # Stream-oriented: split on the stable packet header when possible.
            # Gamepad/PING/PONG/HAPTIC/HELLO packets are self-delimiting by type.
            buf += chunk
            while len(buf) >= 2:
                ptype = P.type_of(bytes(buf[:1]))
                sizes = {P.TYPE_GAMEPAD: P.GAMEPAD_SIZE,
                         P.TYPE_PING: P.PING_SIZE,
                         P.TYPE_PONG: P.PONG_SIZE,
                         P.TYPE_HAPTIC: P.HAPTIC_SIZE,
                         P.TYPE_HELLO: 1}
                size = sizes.get(ptype)
                if size is None:
                    del buf[0]
                    continue
                if len(buf) < size:
                    break
                pkt = bytes(buf[:size])
                del buf[:size]
                self._handle_datagram(pkt, addr, reliable=True, via_udp=False)
        with self._tcp_lock:
            if conn in self._tcp_clients:
                self._tcp_clients.remove(conn)
        print(f"[tcp] client disconnected: {addr}")
        try:
            conn.close()
        except OSError:
            pass

    # ------------------------------------------------------------------ #
    def _disc_loop(self):
        while self.running:
            try:
                data, addr = self._disc_sock.recvfrom(2048)
            except socket.timeout:
                continue
            except OSError:
                break
            # Only reply to HELLO packets (or legacy discovery that pings).
            try:
                if P.type_of(data) == P.TYPE_HELLO:
                    beacon = make_beacon(self.name,
                                         udp_port=self.udp_port,
                                         tcp_port=self.tcp_port)
                    self._disc_sock.sendto(beacon, addr)
                    print(f"[disc] discovery reply -> {addr}")
            except Exception:
                continue

    def _handle_datagram(self, data, addr, reliable, via_udp):
        try:
            ptype = P.type_of(data)
        except ValueError:
            return
        if ptype == P.TYPE_GAMEPAD:
            self._apply_gamepad(data)
        elif ptype == P.TYPE_MOUSE:
            self._apply_mouse(data)
        elif ptype == P.TYPE_KEY:
            self._apply_key(data)
        elif ptype == P.TYPE_PING:
            self._handle_ping(data, addr, via_udp)
        elif ptype == P.TYPE_HELLO:
            # Reply on the discovery channel is handled in _disc_loop; but if a
            # HELLO arrives on the data UDP port, answer with a beacon too.
            beacon = make_beacon(self.name, self.udp_port, self.tcp_port)
            try:
                self._udp_sock.sendto(beacon, addr)
            except OSError:
                pass
        # PONG / HAPTIC from client are not expected here.

    def _apply_gamepad(self, data):
        try:
            btn_lo, btn_hi, lx, ly, rx, ry, l2, r2 = P.decode_gamepad(data)
        except ValueError:
            return
        self.gamepad.apply_gamepad(btn_lo, btn_hi, lx, ly, rx, ry, l2, r2)
        if self._on_state:
            try:
                self._on_state(btn_lo, btn_hi, lx, ly, rx, ry, l2, r2)
            except Exception:
                pass

    def _apply_mouse(self, data):
        try:
            dx, dy, buttons = P.decode_mouse(data)
        except ValueError:
            return
        self.gamepad.apply_mouse(dx, dy, buttons)

    def _apply_key(self, data):
        try:
            keycode, pressed = P.decode_key(data)
        except ValueError:
            return
        self.gamepad.apply_key(keycode, bool(pressed))
        if self._on_key:
            try:
                self._on_key(keycode, bool(pressed))
            except Exception:
                pass

    def _handle_ping(self, data, addr, via_udp):
        try:
            ts, seq = P.decode_pingpong(data)
        except ValueError:
            return
        self._latency_seq = seq
        now = int(time.time() * 1000)
        pong = P.encode_pong(now, seq)
        if via_udp:
            if self._udp_sock:
                try:
                    self._udp_sock.sendto(pong, addr)
                except OSError:
                    return
        else:
            with self._tcp_lock:
                for c in list(self._tcp_clients):
                    if c.fileno() == -1:
                        continue
                    try:
                        c.send(pong)
                    except OSError:
                        pass
        self.latency_ms = max(0, now - ts)

    # ------------------------------------------------------------------ #
    def send_haptic(self, duration_ms, intensity, motor=0):
        """Send a HAPTIC command to the connected TCP client."""
        pkt = P.encode_haptic(duration_ms, intensity, motor)
        with self._tcp_lock:
            clients = list(self._tcp_clients)
        for c in clients:
            try:
                c.send(pkt)
            except OSError:
                pass
