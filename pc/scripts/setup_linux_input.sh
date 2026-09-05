#!/usr/bin/env bash
# Give your Linux user access to /dev/uinput so PulsePad can create the
# virtual gamepad that gamepad testers / games see. Run as root (sudo).
#
#   sudo ./setup_linux_input.sh
#
# After this, the permission survives reboots, so you never need sudo for
# PulsePad again. Verify with:  python3 pulsepad_gui.py
set -euo pipefail

echo "[1/3] Installing udev rule so /dev/uinput is writable by the input group..."
sudo tee /etc/udev/rules.d/99-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0666"
EOF

echo "[2/3] Making PulsePad virtual devices world-readable for any app..."
# Emulators read our virtual gamepad straight from /dev/input/event* via SDL2
# (PPSSPP, Steam, browsers, retroarch...). Those nodes are normally 660
# root:input, so create an explicit rule for the PulsePad nodes.  nowatch
# stops udev from re-triggering the input parent device endlessly.
sudo tee /etc/udev/rules.d/99-pulsepad-input.rules >/dev/null <<'EOF'
KERNEL=="event*", SUBSYSTEM=="input", ATTRS{name}=="PulsePad*", MODE="0666", OPTIONS+="nowatch"
KERNEL=="js*",   SUBSYSTEM=="input", ATTRS{name}=="PulsePad*", MODE="0666", OPTIONS+="nowatch"
EOF

echo "[3/3] Reloading rules and fixing current perms..."
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo chmod 666 /dev/uinput
ls -la /dev/uinput

echo
echo "Done. PulsePad can now create the virtual gamepad and every app"
echo "  (including emulators) can read it."
echo "Test it:  open the PulsePad Control Center, Start Daemon, then press"
echo "  buttons in the phone app to watch the built-in Gamepad tester."
echo "CLI-only: python3 simulate_phone.py --host 127.0.0.1"
echo "  and watch it with:  sudo apt install joystick && jstest /dev/input/js0"