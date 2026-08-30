#!/usr/bin/env bash
# Build the PulsePad Control Center as a single .app for macOS (and a CLI app).
# Run this on a macOS machine. Produces: dist/PulsePad.app  (double-clickable)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/3] Installing build dependency (pyinstaller)..."
python3 -m pip install --upgrade pip
python3 -m pip install pyinstaller

echo "[2/3] Building macOS app bundle..."
python3 -m PyInstaller packaging/pulsepad_gui.spec --noconfirm --clean

echo "[3/3] Done."
echo
echo "Your app bundle is at:"
echo "  dist/PulsePad.app"
echo "Drag it to /Applications or your Desktop and double-click to run."
echo "If macOS complains about an unidentified developer, right-click the app"
echo "and choose Open, or run:  xattr -dr com.apple.quarantine dist/PulsePad.app"
