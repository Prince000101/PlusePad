# Packaging the PulsePad PC app

These scripts bundle the Python Control Center (the Tkinter GUI) into a
standalone app that runs without Python installed on the target machine.

Build on each OS separately to get that OS's binary:

| Platform | Run this        | Output                           |
|----------|-----------------|----------------------------------|
| Windows  | `build_windows.bat` | `dist/PulsePad.exe` (single file) |
| macOS    | `build_mac.sh`      | `dist/PulsePad.app` (bundle)    |
| Linux    | `build_linux.sh`    | `dist/PulsePad` (single executable) |
| (any)    | `pyinstaller pulsepad_gui.spec` | same as above, using whatever OS you are on |

All builds use [PyInstaller](https://pyinstaller.org/); the scripts install it
for you (on Linux, into a venv if the system pip is PEP-668 locked).

## Quick start

```bash
# Windows
build_windows.bat

# macOS
./build_mac.sh

# Linux
./build_linux.sh
```

Copy `dist/PulsePad` (`.exe` / `.app`) anywhere and double-click to run.

## Notes

- Linux prerequisites: `python3-tk` and `pip3` (`sudo apt install python3-tk python3-pip`).
- Linux first run: the app prompts once (pkexec or sudo) to install a udev
  rule so emulators can read the virtual controller.  The rule persists.
- Windows SmartScreen may warn on first run because the exe is not
  code-signed.  "More info -> Run anyway".
- macOS Gatekeeper: right-click the app -> Open, or
  `xattr -dr com.apple.quarantine dist/PulsePad.app`.
- Size: roughly 8-20 MB single file depending on OS.
- The app is self-contained and portable; no install needed.

## What the packaged app does

Same as `python3 pulsepad_gui.py`: a window to start/stop the daemon, show
live status (server state, gamepad backend, connected phones split by
USB/Wi-Fi, latency, PC IP), run the USB wired helper (`⚡ USB (cable)` runs
`adb reverse tcp:5005 tcp:5005` and verifies it), show a QR code the phone
scans to connect over Wi-Fi, a live gamepad/keyboard tester, and a Help tab
covering the Wi-Fi and USB steps.  Closing the window stops the daemon.