#!/usr/bin/env bash
# Build the PulsePad Control Center as a single executable for Linux.
# Run this on a Linux machine. Produces: dist/PulsePad  (chmod +x and run /
# double-click).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/3] Checking build dependency (pyinstaller)..."
PY=python3
if ! python3 -c "import PyInstaller" >/dev/null 2>&1; then
    if python3 -m pip install pyinstaller >/dev/null 2>&1; then
        true
    else
        # Debian 12+/Ubuntu 23.10+ block pip outside a venv (PEP 668).
        # Build in a throwaway venv so there's no risk to the system Python.
        VENV=/tmp/pulsepad-venv
        python3 -m venv "$VENV"
        "$VENV/bin/pip" install --quiet pyinstaller uinput
        PY="$VENV/bin/python"
    fi
fi
echo "PyInstaller ready ($PY)"

echo "[2/3] Building Linux executable..."
"$PY" -m PyInstaller packaging/pulsepad_gui.spec --noconfirm --clean

echo "[3/3] Done."
echo
echo "Your portable app is at:"
echo "  dist/PulsePad"
echo "Copy it to your Desktop or anywhere and run / double-click."
echo "Note: Linux needs python3-tk to build; on Debian/Ubuntu:"
echo "  sudo apt install python3-tk python3-pip"
