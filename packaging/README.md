# 📦 Packaging the PulsePad PC app

These scripts turn the Python **Control Center** (the GUI that starts/stops the
daemon) into a **standalone app** you can drop on your Desktop or anywhere and
double-click — **no Python required** on the target computer.

Build **on each OS separately** to get that OS's app:

| Platform | Run this        | Output you get                          |
|----------|-----------------|-----------------------------------------|
| Windows  | `build_windows.bat` | `dist/PulsePad.exe` (single file)     |
| macOS    | `build_mac.sh`      | `dist/PulsePad.app` (bundle)         |
| Linux    | `build_linux.sh`    | `dist/PulsePad` (single executable) |
| (any)    | `pyinstaller pulsepad_gui.spec` | same as above, using whatever OS you're on |

All builds use [PyInstaller](https://pyinstaller.org/) (`pip install pyinstaller`), done for you by the scripts.

## Quick start

```bash
# Windows
build_windows.bat

# macOS
./build_mac.sh

# Linux
./build_linux.sh
```

Then copy `dist/PulsePad` (`.exe` / `.app`) to your Desktop, `~/bin`, or anywhere — double-click to run.

## Notes

- **Linux prerequisites:** `python3-tk` and `pip3` — `sudo apt install python3-tk python3-pip`.
- **First build on each OS is slow** (bundles the Python runtime + Tkinter); after that it's cached.
- **Windows SmartScreen:** may warn on first run because the exe isn't code-signed. Click *More info → Run anyway*.
- **macOS Gatekeeper:** if blocked, right-click the app → *Open*, or `xattr -dr com.apple.quarantine dist/PulsePad.app`.
- **Size:** roughly 8–20 MB single file depending on OS.
- The app is self-contained and **portable** — no install needed.

## What the packaged app does

Exactly the same as `python3 pulsepad_gui.py`: a small window to **start/stop the PulsePad daemon**, show live connection status (server state, connected phone, latency ms, PC IP), **show a QR code** the phone scans to auto-fill IP + ports, and a log. **Closing the window stops the daemon** — no background processes.
