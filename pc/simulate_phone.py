#!/usr/bin/env python3
"""PulsePad simulated phone.

Streams a fake controller exactly like the Android app does, so you can test
the daemon (client count, latency, virtual gamepad) without a phone.  With
/dev/uinput accessible, the rotating left stick and A-button presses show up
on the PulsePad gamepad device.

Both transports are supported so you can test USB (TCP, the adb-reverse wired
path) and Wi-Fi (UDP) identically:

    TCP  --host=127.0.0.1 --transport=tcp   (same path a wired phone uses)
    UDP  --host=127.0.0.1 --transport=udp   (same path a Wi-Fi phone uses)

Usage:
    python3 simulate_phone.py [--host HOST] [--port PORT] [--transport tcp|udp]
"""

import argparse
import math
import socket
import threading
import time

from pulsepad import protocol as P


def _rotating_state(step_fraction, btn_a, btn_b):
    """Controller snapshot for a rotating left stick + A/B button pattern."""
    lx = int(math.sin(step_fraction * 2 * math.pi) * 32767)
    ly = int(math.cos(step_fraction * 2 * math.pi) * 32767)
    btn = (P.BTN_A if btn_a else 0) | (P.BTN_B if btn_b else 0)
    return btn, lx, ly


class PhoneSimulator:
    """Streams synthetic phone traffic until stop() is called.

    Runs one thread per transport.
    """

    def __init__(self, host="127.0.0.1", port=5006, transport="udp",
                 rate=100):
        self.host = host
        self.port = port
        self.transport = transport
        self.rate = rate
        self._stop_evt = threading.Event()
        self._thread = None
        self._t0 = None

    @property
    def running(self):
        return self._thread is not None and self._thread.is_alive()

    def start(self):
        if self.running:
            return
        self._stop_evt.clear()
        self._t0 = time.time()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self, join_timeout=2.0):
        self._stop_evt.set()
        if self._thread:
            self._thread.join(join_timeout)
            self._thread = None

    # ------------------------------------------------------------------ #
    def _run(self):
        step = 0
        ping_seq = 0
        last_ping = 0.0
        if self.transport == "tcp":
            with socket.create_connection((self.host, self.port),
                                          timeout=0.5) as sock:
                sock.settimeout(0.2)
                sock.sendall(P.encode_hello())
                while not self._stop_evt.is_set():
                    now = time.time()
                    self._send_tcp(sock, step, now >= last_ping)
                    if now - last_ping >= 0.5:
                        last_ping = now
                        ping_seq += 1
                    step += 1
                    self._stop_evt.wait(1.0 / self.rate)
                sock.sendall(P.encode_gamepad(0, 0, 0, 0, 0, 0, 0, 0))
        else:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.sendto(P.encode_hello(), (self.host, self.port))
                while not self._stop_evt.is_set():
                    now = time.time()
                    self._send_udp(sock, step, now >= last_ping)
                    if now - last_ping >= 0.5:
                        last_ping = now
                        sock.sendto(P.encode_ping(int(now * 1000), ping_seq),
                                    (self.host, self.port))
                        ping_seq += 1
                    step += 1
                    self._stop_evt.wait(1.0 / self.rate)
                sock.sendto(P.encode_gamepad(0, 0, 0, 0, 0, 0, 0, 0),
                            (self.host, self.port))

    def _send_tcp(self, sock, step, ping):
        btn, lx, ly = _rotating_state(
            step / 120.0, bool(step % 5 != 0), bool(int(step / 60) % 2))
        sock.sendall(P.encode_gamepad(btn & 0xFF, (btn >> 8) & 0xFF,
                                      lx, ly, 0, 0, 0, 0))
        if ping:
            sock.sendall(P.encode_ping(int(time.time() * 1000), step))

    def _send_udp(self, sock, step, _ping):
        btn, lx, ly = _rotating_state(
            step / 120.0, bool(step % 5 != 0), bool(int(step / 60) % 2))
        sock.sendto(P.encode_gamepad(btn & 0xFF, (btn >> 8) & 0xFF,
                                     lx, ly, 0, 0, 0, 0),
                    (self.host, self.port))


def stream(host="127.0.0.1", port=5006, duration=float("inf"), rate=100,
           transport="udp"):
    """Blocking convenience wrapper (kept for backwards compatibility)."""
    sim = PhoneSimulator(host=host, port=port, transport=transport, rate=rate)
    sim.start()
    try:
        if duration == float("inf"):
            while sim.running:
                time.sleep(0.2)
        else:
            time.sleep(duration)
    finally:
        sim.stop()
        print(f"[sim] done ({sim.transport})")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=5006)
    ap.add_argument("--seconds", type=float, default=float("inf"))
    ap.add_argument("--transport", choices=["tcp", "udp"], default="udp")
    args = ap.parse_args()
    try:
        stream(args.host, args.port, args.seconds, transport=args.transport)
    except KeyboardInterrupt:
        print("\n[sim] stopped")


if __name__ == "__main__":
    main()