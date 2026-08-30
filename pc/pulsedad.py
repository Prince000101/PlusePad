#!/usr/bin/env python3
"""PulsePad daemon entry point.

Works on every PC (Linux, Windows, macOS):

    Linux:   sudo python3 pulsedad.py
    Windows: python pulsedad.py --backend=windows
    Headless: python3 pulsedad.py --no-virtual-device

Requirements:
    Linux:   python-uinput python-evdev (pip install -r requirements.txt)
    Windows: vigem-client             (pip install vigem-client)
    All:     No additional Python packages needed for networking.
"""

import argparse
import sys

from pulsepad import protocol as P
from pulsepad.server import PulsePadServer
from pulsepad.virtual_device import VirtualGamepad


def main():
    parser = argparse.ArgumentParser(description="PulsePad daemon")
    parser.add_argument("--tcp-port", type=int, default=5005,
                        help="TCP port for USB mode (adb reverse)")
    parser.add_argument("--udp-port", type=int, default=5006,
                        help="UDP port for Wi-Fi streaming")
    parser.add_argument("--disc-port", type=int, default=54321,
                        help="UDP discovery port (auto-find)")
    parser.add_argument("--name", default="PulsePad", help="Server beacon name")
    parser.add_argument("--no-virtual-device", action="store_true",
                        help="Do not create a virtual gamepad (server-only mode)")
    parser.add_argument("--backend", choices=["auto", "linux", "windows"],
                        default="auto",
                        help="Virtual gamepad backend (auto detects from OS)")
    args = parser.parse_args()

    if args.no_virtual_device:
        gamepad = VirtualGamepad(backend="null")
    else:
        gamepad = VirtualGamepad(backend=args.backend)
        if not gamepad.enabled:
            if sys.platform.startswith("linux"):
                print("\n  To fix: run with sudo, or install python-uinput:\n"
                      "    pip3 install python-uinput python-evdev\n"
                      "    sudo chmod 666 /dev/uinput\n")
            elif sys.platform.startswith("win"):
                print("\n  To fix on Windows:\n"
                      "    1. Install ViGEmBus: https://github.com/ViGEm/ViGEmBus\n"
                      "    2. pip install vigem-client\n")
            else:
                print("\n  macOS virtual gamepad not yet implemented.\n"
                      "  The daemon still runs as a network server.\n")

    server = PulsePadServer(
        gamepad,
        tcp_port=args.tcp_port,
        udp_port=args.udp_port,
        discovery_port=args.disc_port,
        name=args.name,
    )

    print("=" * 50)
    print("  PulsePad Daemon v3  (binary protocol, cross-platform)")
    print("=" * 50)
    try:
        server.start()
        while server.running:
            import time
            time.sleep(2)
            if server.gamepad.enabled and server.latency_ms:
                print(f"   latency: {server.latency_ms} ms", end="\r", flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        server.stop()
        gamepad.close()
        print("\n[+] daemon stopped")


if __name__ == "__main__":
    main()
