#!/usr/bin/env python3
"""PulsePad simulated phone.

Streams a fake controller over UDP exactly like the Android app does, so you
can test the daemon + Control Center (client count, latency, virtual gamepad)
without a phone.  Useful with a gamepad tester: with /dev/uinput accessible the
rotating left stick and A-button presses show up on the PulsePad device.

Usage:
    python3 simulate_phone.py [--host HOST] [--port PORT]

    --host  default 127.0.0.1   (the PC running the daemon)
    --port  default 5006        (the daemon's UDP port)
"""

import argparse
import math
import socket
import time

from pulsepad import protocol as P


def stream(host="127.0.0.1", port=5006, duration=float("inf"), rate=100):
    target = (host, port)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(P.encode_hello(), target)
    print(f"[sim] streaming to {host}:{port}  (Ctrl-C to stop)")
    t0 = time.time()
    seq = 0
    last_ping = 0.0
    while time.time() - t0 < duration:
        now = time.time()
        t = (now - t0) * 2.0
        lx = int(math.sin(t) * 32767)
        ly = int(math.cos(t) * 32767)
        # A is held, B pulses, so every snapshot has at least one button set.
        btn = P.BTN_A | (P.BTN_B if int(now * 4) % 2 else 0)
        s.sendto(P.encode_gamepad(btn & 0xFF, (btn >> 8) & 0xFF,
                                  lx, ly, 0, 0, 0, 0), target)
        if now - last_ping > 0.5:
            last_ping = now
            s.sendto(P.encode_ping(int(now * 1000), seq), target)
        seq += 1
        time.sleep(1.0 / rate)
    s.sendto(P.encode_gamepad(0, 0, 0, 0, 0, 0, 0, 0), target)
    s.close()
    print("[sim] done")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=5006)
    ap.add_argument("--seconds", type=float, default=float("inf"))
    args = ap.parse_args()
    try:
        stream(args.host, args.port, args.seconds)
    except KeyboardInterrupt:
        print("\n[sim] stopped")


if __name__ == "__main__":
    main()