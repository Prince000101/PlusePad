"""End-to-end server tests over real loopback sockets (no uinput required).

The VirtualGamepad falls back to a NullDevice in this environment; we verify
that the full receive->decode->apply pipeline runs without error and that
latency PING/PONG and HAPTIC flows work.
"""

import socket
import struct
import threading
import time
import unittest

from pulsepad import protocol as P
from pulsepad.server import (PulsePadServer, UDP_PORT, TCP_PORT,
                             DISCOVERY_PORT, make_beacon)
from pulsepad.virtual_device import VirtualGamepad


class _RecordingPad(VirtualGamepad):
    """Captures every apply_gamepad call so we can assert on decoded state."""

    def __init__(self):
        super().__init__()
        self.calls = []

    def apply_gamepad(self, *args):
        self.calls.append(args)


class TestServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tcp_port = 15105
        cls.udp_port = 15106
        cls.disc_port = 15107
        cls.pad = _RecordingPad()
        cls.server = PulsePadServer(
            cls.pad, tcp_port=cls.tcp_port, udp_port=cls.udp_port,
            discovery_port=cls.disc_port)
        cls.server.start()
        time.sleep(0.3)

    def setUp(self):
        # Clear stale UDP peers and TCP clients so tests don't leak state.
        with self.server._udp_peers_lock:
            self.server._udp_peers.clear()
        with self.server._tcp_lock:
            for c in list(self.server._tcp_clients):
                try:
                    c.close()
                except OSError:
                    pass
            self.server._tcp_clients.clear()
        self.pad.calls.clear()

    @classmethod
    def tearDownClass(cls):
        cls.server.stop()

    def _udp_gamepad(self):
        pkt = P.encode_gamepad(
            P.BTN_A | P.BTN_X, P.BTN_DPAD_UP | P.BTN_R2,
            1000, -2000, 3000, -4000, 200, 50)
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.sendto(pkt, ("127.0.0.1", self.udp_port))
        s.close()

    def test_udp_gamepad_flow(self):
        self._udp_gamepad()
        deadline = time.time() + 2.0
        found = None
        while time.time() < deadline:
            for c in self.pad.calls:
                if c[0] & P.BTN_A:
                    found = c
                    break
            if found:
                break
            time.sleep(0.01)
        self.assertIsNotNone(found, "gamepad packet with BTN_A not processed")
        btn_lo, btn_hi, lx, ly, rx, ry, l2, r2 = found
        self.assertEqual(btn_lo & P.BTN_X, P.BTN_X)
        self.assertEqual(btn_hi & P.BTN_DPAD_UP, P.BTN_DPAD_UP)
        self.assertEqual(btn_hi & P.BTN_R2, P.BTN_R2)
        self.assertEqual(lx, 1000)
        self.assertEqual(r2, 50)

    def test_tcp_gamepad_flow_with_partial_reads(self):
        pkt = P.encode_gamepad(
            P.BTN_B | P.BTN_Y | P.BTN_START, P.BTN_L3, -5000, 0, 0, 0, 0, 255)
        s = socket.create_connection(("127.0.0.1", self.tcp_port), timeout=2)
        # Deliver in awkward chunks to exercise stream reassembly.
        for i in range(0, len(pkt), 3):
            s.sendall(pkt[i:i + 3])
            time.sleep(0.001)
        s.close()
        deadline = time.time() + 2.0
        while time.time() < deadline or True:
            found = [c for c in self.pad.calls if c[0] & P.BTN_B]
            if found:
                break
            time.sleep(0.01)
        found = [c for c in self.pad.calls if c[0] & P.BTN_B]
        self.assertTrue(found, "TCP packet not decoded with partial reads")
        btn_lo, btn_hi, _, _, _, _, _, r2 = found[-1]
        self.assertEqual(btn_hi & P.BTN_L3, P.BTN_L3)
        self.assertEqual(r2, 255)

    def test_ping_pong_udp(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(2)
        s.sendto(P.encode_ping(5000, seq=7), ("127.0.0.1", self.udp_port))
        data, _ = s.recvfrom(64)
        s.close()
        self.assertEqual(P.type_of(data), P.TYPE_PONG)
        ts, seq = P.decode_pingpong(data)
        self.assertEqual(seq, 7)
        self.assertGreaterEqual(ts, 5000)

    def test_discovery_hello(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(2)
        s.sendto(P.encode_hello(), ("127.0.0.1", self.disc_port))
        data, _ = s.recvfrom(128)
        s.close()
        parsed = parse_beacon(data)
        self.assertIsNotNone(parsed)
        udp_port, tcp_port, name = parsed
        self.assertEqual((udp_port, tcp_port), (self.udp_port, self.tcp_port))
        self.assertEqual(name, "PulsePad")

    def test_hello_on_data_port_gets_beacon(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(2)
        s.sendto(P.encode_hello(), ("127.0.0.1", self.udp_port))
        data, _ = s.recvfrom(128)
        s.close()
        self.assertIsNotNone(parse_beacon(data))

    def test_haptic_roundtrip_over_tcp(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        s.connect(("127.0.0.1", self.tcp_port))
        # Give the server accept thread time to register the client.
        time.sleep(0.3)
        self.server.send_haptic(duration_ms=300, intensity=0.9, motor=1)
        data = s.recv(64)
        s.close()
        self.assertEqual(P.type_of(data), P.TYPE_HAPTIC)
        d, i, m = P.decode_haptic(data)
        self.assertEqual((d, m), (300, 1))
        self.assertAlmostEqual(i, 0.9, places=1)

    def test_udp_phone_counted_then_pruned(self):
        # A Wi-Fi phone is tracked by last-seen; it must register immediately
        # and decay away once it stops sending (no phantom "connected").
        old = PulsePadServer._UDP_PEER_TIMEOUT
        PulsePadServer._UDP_PEER_TIMEOUT = 0.5
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.sendto(P.encode_gamepad(0, 0, 0, 0, 0, 0, 0, 0),
                     ("127.0.0.1", self.udp_port))
            time.sleep(0.2)  # let the server thread receive the datagram
            self.assertEqual(self.server.client_count, 1)
            # TCP clients should be zero in this sub-test.
            tcp, udp = self.server.transport_counts
            self.assertEqual(tcp, 0)
            self.assertEqual(udp, 1)
            deadline = time.time() + 3.0
            while self.server.client_count:
                if time.time() > deadline:
                    break
                time.sleep(0.05)
            self.assertEqual(self.server.client_count, 0,
                             "stale Wi-Fi peer was not pruned")
            s.close()
        finally:
            PulsePadServer._UDP_PEER_TIMEOUT = old

    def test_simulated_phone_streams_and_counts(self):
        # The simulate_phone helper must be treated like a real phone:
        # it registers as a UDP peer, streams controller state and PINGs.
        import simulate_phone
        t = threading.Thread(target=simulate_phone.stream,
                             kwargs={"host": "127.0.0.1",
                                     "port": self.udp_port,
                                     "duration": 1.0},
                             daemon=True)
        t.start()
        deadline = time.time() + 3.0
        saw_button = False
        while time.time() < deadline:
            for c in self.pad.calls:
                if c[0] & P.BTN_A:
                    saw_button = True
                    break
            if saw_button and self.server.client_count >= 1:
                break
            time.sleep(0.02)
        t.join(timeout=3)
        self.assertTrue(saw_button,
                        "simulated phone never sent a BTN_A snapshot")
        self.assertGreaterEqual(self.server.client_count, 1,
                                "simulated phone not counted as connected")

    def test_transport_counts_split(self):
        # TCP clients and UDP peers are accounted separately.
        # Pre-seed a UDP peer so we see both counts split.
        s_udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s_udp.sendto(P.encode_gamepad(0, 0, 0, 0, 0, 0, 0, 0),
                     ("127.0.0.1", self.udp_port))
        time.sleep(0.2)  # let server thread process the datagram
        s_tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s_tcp.settimeout(2)
        s_tcp.connect(("127.0.0.1", self.tcp_port))
        # Poll until the accept thread registers the TCP client, sending keep
        # -alive PINGs so the server's recv loop never sees the connection drop.
        deadline = time.time() + 2.0
        kept = 0
        while time.time() < deadline:
            s_tcp.sendall(P.encode_ping(int(time.time() * 1000), kept))
            kept += 1
            tc = self.server.transport_counts
            if tc[0] >= 1 and tc[1] >= 1:
                break
            time.sleep(0.05)
        else:
            tc = self.server.transport_counts
        tcp, udp = tc
        self.assertGreaterEqual(tcp, 1, "TCP client not tracked")
        self.assertGreaterEqual(udp, 1, "UDP peer not tracked")
        s_tcp.close()
        s_udp.close()
        time.sleep(0.3)


from pulsepad.server import parse_beacon  # noqa: E402


if __name__ == "__main__":
    unittest.main()
