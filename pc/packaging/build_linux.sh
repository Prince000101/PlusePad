#!/usr/bin/env bash
# Build the PulsePad Control Center as a single executable for Linux.
# Run this on a Linux machine. Produces: dist/PulsePad  (chmod +x and run /
# double-click).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/3] Installing build dependency (pyinstaller)..."
python3 -m pip install --upgrade pip
python3 -m pip install pyinstaller

echo "[2/3] Building Linux executable..."
python3 -m PyInstaller packaging/pulsepad_gui.spec --noconfirm --clean

echo "[3/3] Done."
echo
echo "Your portable app is at:"
echo "  dist/PulsePad"
echo "Copy it to your Desktop or anywhere and run / double-click."
echo "Note: Linux needs python3-tk to build; on Debian/Ubuntu:"
echo "  sudo apt install python3-tk python3-pip"
