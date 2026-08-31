#!/usr/bin/env bash
# Give your Linux user access to /dev/uinput so PulsePad can create the
# virtual gamepad that gamepad testers / games see. Run as root (sudo).
#
#   sudo ./setup_linux_input.sh
#
# After this, the permission survives reboots, so you never need sudo for
# PulsePad again. Verify with:  python3 pulsepad_gui.py
set -euo pipefail

echo "[1/2] Installing udev rule so /dev/uinput is writable by the video group..."
sudo tee /etc/udev/rules.d/99-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0666"
EOF

echo "[2/2] Reloading rules and fixing current perms..."
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo chmod 666 /dev/uinput
ls -la /dev/uinput

echo
echo "Done. PulsePad can now create the virtual gamepad."
echo "Test it:  Start Daemon + Simulate Phone, then open a gamepad tester."
echo "CLI-only: python3 simulate_phone.py --host 127.0.0.1"
echo "  and watch it with:  sudo apt install joystick && jstest /dev/input/js0"