# 🎮 PulsePad

**Turn your Android phone into a zero-latency wireless game controller for your PC** — perfect for PS2 (PCSX2), PSP (PPSSPP), Steam, and any game that uses a standard gamepad.

Free • Open source • Cross-platform (Windows / Linux / macOS) • No accounts, no cloud, no bloat.

---

## ✨ Features

- **Real low latency** — self-contained binary protocol, coalesced 250 Hz sampling (USB ~1–5 ms, Wi-Fi ~5–15 ms).
- **Full PS2 / PSP pad** — D-pad, L1/R1/L2/R2 (analog + digital), L3/R3, SELECT/START, dual analog sticks.
- **Works on every PC** — Linux `uinput`, Windows ViGEmBus, macOS; graceful fallback if no driver.
- **Hassle-free connection** — one-tap Wi-Fi **auto-discovery** *or* **QR scan** of the PC screen (auto-fills IP + ports) *or* ultra-stable USB via `adb reverse`.
- **Zero-config desktop GUI** — a **Control Center** window to start/stop the daemon, watch live connection status & latency, and **display a QR code** you scan with the phone to connect instantly. Closing the window stops the daemon completely.
- **Auto-reconnect** — link recovers automatically; real PING/PONG latency display.
- **Haptic feedback** — rumble support, plus Gamepad / PSP / PS5 / Mouse / Keyboard layouts on the phone.
- **Tested** — 24 daemon unit tests (real sockets) + Flutter analyze clean & widget tests green.

---

## 🧩 How it works

```
┌───────────────┐   USB (TCP:5005)   ┌──────────────────┐
│  Phone App    │  ───────────────►  │  PC Daemon       │
│  (Flutter)    │   Wi-Fi (UDP:5006) │  (pulsedad)      │
└──────┬────────┘  Auto-find:54321   └────────┬─────────┘
       │                                      │ uinput / ViGEm
       │   13-byte full-state snapshot        ▼
       └────────────────────────────►  Virtual Gamepad
                                       (PCSX2, PPSSPP,
                                        Steam, native games)
```

The app sends **complete snapshots** (no history / ordering) — a dropped packet never corrupts state; the very next packet is the full truth.

---

## 📦 Project layout

```
phone/                           # Flutter (Dart) — the Android controller app
  lib/services/protocol.dart          byte-compatible binary protocol
  lib/services/connection_manager.dart  UDP/TCP, discovery, reconnect, latency
  lib/screens/controller_screen.dart    gamepad/PSP/PS5/mouse/keyboard layouts
  lib/screens/connection_screen.dart    connect + auto-discover UI
  lib/screens/qr_scanner_screen.dart    scan the PC's QR code to auto-fill IP/ports
pc/                              # Python 3 daemon — creates the virtual gamepad
  pulsedad.py                      headless CLI daemon
  pulsepad_gui.py                  Control Center desktop GUI (Tkinter)
  pulsepad/protocol.py             binary protocol
  pulsepad/server.py               TCP/UDP/discovery server + haptics
  pulsepad/virtual_device.py       cross-platform virtual gamepad backends
  pulsepad/qr_config.py            shared QR connection payload format
  tests/                           24 unit tests (real loopback sockets)
  packaging/                       PyInstaller spec + per-OS build scripts
```

---

## 🖥️ PC setup

### Option A — Desktop GUI app (easiest, recommended)

The **Control Center** GUI starts/stops the daemon, shows live status (server state, phone connected, latency, PC IP), and can **show a QR code** that encodes the PC's address + ports. Scan it with the phone app to connect instantly — no typing.

```bash
cd pc
pip install -r requirements.txt        # only the lines matching your OS

# Linux / macOS:
python3 pulsepad_gui.py
# Windows:
python  pulsepad_gui.py
```

### Option B — Headless CLI

```bash
cd pc
# Linux (virtual pad via uinput):
sudo python3 pulsedad.py                        # or: sudo chmod 666 /dev/uinput
# Windows (install ViGEmBus, then):
python pulsedad.py --backend=windows
```

> No sudo needed to test the server / Wi-Fi: add `--no-virtual-device`.

### Option C — Package a standalone desktop app (no Python needed)

One command per OS produces a single portable app you can drop on the Desktop:

```bash
# On Windows → dist/PulsePad.exe
cd pc && cmd /c packaging/build_windows.bat

# On macOS   → dist/PulsePad.app
cd pc && ./packaging/build_mac.sh

# On Linux   → dist/PulsePad (single executable)
cd pc && ./packaging/build_linux.sh
```

Build on each OS to get that OS's binary. See [`packaging/README.md`](pc/packaging/README.md).

---

## 📱 Build & install the phone app

```bash
cd phone
flutter pub get
flutter build apk --release
# APK output:  build/app/outputs/flutter-apk/app-release.apk
# Install:     adb install build/app/outputs/flutter-apk/app-release.apk
```

Or `flutter run` with a device connected.

---

## 🔗 Connect the phone

**Wi-Fi (wireless, zero-config):**
1. Phone and PC on the same network.
2. Tap **Connect** — the app auto-discovers the PC (or enter the IP shown in the Control Center).

**Wi-Fi via QR (no typing at all):**
1. In the Control Center click **Show QR**.
2. On the phone tap **Scan QR** and point it at the PC screen — the app auto-fills the IP, ports and mode, then just tap **Connect**.

**USB (lowest latency, no Wi-Fi):**
```bash
adb reverse tcp:5005 tcp:5005
```
Then open the app, tap **Connect**, pick USB.

Then choose a layout (Gamepad / PSP / PS5 / Mouse / Keyboard) and play.

---

## 🎮 Virtual controller mapping

| Input | uinput code |
|-------|-------------|
| A / B / X / Y | BTN_A / BTN_B / BTN_X / BTN_Y |
| L1 / R1 | BTN_TL / BTN_TR |
| L2 / R2 | ABS_Z / ABS_RZ (analog 0–255) **+** BTN_TL2 / BTN_TR2 (digital) |
| SELECT / START | BTN_SELECT / BTN_START |
| L3 / R3 | BTN_THUMBL / BTN_THUMBR |
| D-pad | ABS_HAT0X / ABS_HAT0Y |
| Sticks | ABS_X / ABS_Y / ABS_RX / ABS_RY (−32768..32767) |

---

## 🔐 Protocol (binary, self-contained)

Each message is delimited by a header byte: `PROTOCOL_VERSION(4) | TYPE(4)`. Multi-byte numbers are little-endian.

| Type | Byte | Size | Payload |
|------|-----:|-----:|---------|
| GAMEPAD | 1 | 13 | btns_lo, btns_hi, LX, LY, RX, RY (i16), L2, R2 (u8) |
| PING | 2 | 11 | 8-byte random token |
| PONG | 3 | 11 | echoes the PING token |
| HAPTIC | 4 | 4 | rumble amount |
| HELLO | 5 | 1 | discovery request → beacon reply offers ports |

Beacon: `"PPB1"` + udp_port(2,big) + tcp_port(2,big) + len + name.

---

## 🧪 Running the tests

```bash
# pc — 24 tests, real sockets, no root needed
cd pc && python3 -m unittest discover -s tests -v

# app
cd phone && flutter analyze && flutter test
```

---

## 🖥️ Platform support

| Platform | Virtual gamepad | Notes |
|----------|-----------------|-------|
| Linux | uinput | needs `/dev/uinput` (sudo) |
| Windows | ViGEmBus | install bus + `pip install vigem-client` |
| macOS | — (network only) | daemon runs; virtual pad not yet implemented |
| Headless | none (null) | server / discovery still work — good for testing |

---

## 📄 License
MIT — free to use, modify, and share.
