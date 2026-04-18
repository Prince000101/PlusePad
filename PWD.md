# PulsePad - Technical Build Document

## What This App Does
Turns your phone into a low-latency game controller for Linux PC via USB (ADB) or Wi-Fi (UDP). Creates a virtual gamepad using Linux uinput.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile App | Flutter (Android) |
| Desktop Daemon | Python |
| Virtual Controller | Linux uinput |
| Communication | ADB forwarding / UDP sockets |
| Input System | evdev |

---

## System Architecture

```
┌─────────────────┐        USB/WiFi        ┌─────────────────┐
│   Flutter App   │ ────────────────────── │  Python Daemon   │
│   (Android)     │   tcp:5005 / udp:5006  │   (Linux PC)    │
└────────┬────────┘                         └────────┬────────┘
         │                                          │
         │  Input packets                           │  uinput events
         │  (JSON/bytes)                           │  (/dev/input)
         └──────────────────────────────────────────┘
                            ↓
                   ┌─────────────────┐
                   │  Virtual Gamepad │
                   │  /dev/input/js0  │
                   └─────────────────┘
```

---

## Data Models

### Input Packet (Mobile → Desktop)
```json
{
  "type": "INPUT",
  "timestamp": 1712345678900,
  "buttons": {
    "A": 1,
    "B": 0,
    "X": 0,
    "Y": 1
  },
  "axes": {
    "LX": 0.45,
    "LY": -0.12,
    "RX": 0.0,
    "RY": 0.0
  }
}
```

### Control Packet (Desktop → Mobile)
```json
{
  "type": "HAPTIC",
  "duration": 100,
  "intensity": 0.8
}
```

---

## Input Mapping (Standard Gamepad)

| Button | Code | Axis/Button |
|--------|------|-------------|
| A | BTN_A | Digital |
| B | BTN_B | Digital |
| X | BTN_X | Digital |
| Y | BTN_Y | Digital |
| L1 | BTN_TL | Digital |
| R1 | BTN_TR | Digital |
| L2 | BTN_Z | Analog 0-1 |
| R2 | BTN_RZ | Analog 0-1 |
| Left Stick X | ABS_X | Axis -1 to 1 |
| Left Stick Y | ABS_Y | Axis -1 to 1 |
| Right Stick X | ABS_RX | Axis -1 to 1 |
| Right Stick Y | ABS_RY | Axis -1 to 1 |

---

## UI Screens

### Screen 1: ConnectionScreen
```
┌─────────────────────────────────┐
│                                 │
│           PulsePad              │
│     [Controller Icon]           │
│                                 │
│   Connection Mode:              │
│   ┌─────────────────────────┐   │
│   │  ○ USB (Recommended)     │   │
│   │  ○ Wi-Fi                │   │
│   └─────────────────────────┘   │
│                                 │
│   ┌─────────────────────────┐   │
│   │      CONNECT            │   │
│   └─────────────────────────┘   │
│                                 │
│   Status: Searching...          │
│                                 │
└─────────────────────────────────┘
```

### Screen 2: ControllerScreen
```
┌─────────────────────────────────┐
│  🔗 USB Connected    ⚙️ Settings │
├─────────────────────────────────┤
│                                 │
│                                 │
│    ┌─────────────────────┐     │
│    │                     │     │
│    │    ANALOG STICK     │     │
│    │       (●  )         │     │
│    │                     │     │
│    └─────────────────────┘     │
│                                 │
│  [Y]                       [X] │
│                                 │
│        [Select]                 │
│                                 │
│   [B]                     [A]   │
│                                 │
│                                 │
│  ┌──────┐              ┌──────┐│
│  │  L1  │              │  R1  ││
│  └──────┘              └──────┘│
│  ┌──────┐              ┌──────┐│
│  │  L2  │              │  R2  ││
│  └──────┘              └──────┘│
│                                 │
│  Latency: 4ms                   │
└─────────────────────────────────┘
```

### Screen 3: SettingsScreen
```
┌─────────────────────────────────┐
│ ← Back        Settings          │
├─────────────────────────────────┤
│                                 │
│  Connection                      │
│  ┌─────────────────────────┐   │
│  │ USB Port: 5037        ▼ │   │
│  │ IP Address: 192.168.1.x│   │
│  └─────────────────────────┘   │
│                                 │
│  Controller                      │
│  ┌─────────────────────────┐   │
│  │ Dead Zone: [────●───]   │   │
│  │ Vibration: [ON]        │   │
│  │ Stick Sensitivity: 1.0x│   │
│  └─────────────────────────┘   │
│                                 │
│  Advanced                        │
│  ┌─────────────────────────┐   │
│  │ Packet Rate: [120 Hz]▼ │   │
│  │ Protocol: [UDP]        │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  CALIBRATE CONTROLLER   │   │
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

---

## Key Features (MVP)

1. **USB Connection** - ADB port forwarding, near-zero latency
2. **Wi-Fi Connection** - UDP streaming fallback
3. **Virtual Gamepad** - Linux uinput driver
4. **Button Input** - A, B, X, Y, L1, R1, L2, R2
5. **Analog Stick** - Left stick with deadzone
6. **Real-time Haptics** - Vibration feedback
7. **Latency Display** - Show current latency

---

## Module Breakdown

### Module 1: Connection Manager
- ADB device detection
- Port forwarding setup
- UDP socket management
- Auto-reconnection

### Module 2: Input Capture (Flutter)
- Touch joystick handling
- Button press detection
- Analog stick calculation
- Input state management

### Module 3: Packet Encoder
- JSON/MessagePack encoding
- Binary packet option
- Checksum calculation
- Sequence numbering

### Module 4: Network Stream
- TCP socket (USB mode)
- UDP socket (Wi-Fi mode)
- Heartbeat packets
- Bandwidth management

### Module 5: Desktop Daemon (Python)
- Socket server
- Packet decoding
- Input normalization
- uinput injection

### Module 6: Virtual Controller
- uinput device creation
- Event type mapping
- ABS_X/Y for sticks
- BTN_* for buttons

---

## Development Timeline

| Week | Task |
|------|------|
| 1 | Project setup, Flutter UI, Python daemon skeleton |
| 2 | USB connection via ADB |
| 3 | Input capture, packet encoding |
| 4 | uinput integration, button mapping |
| 5 | Analog stick, deadzone |
| 6 | UDP Wi-Fi mode |
| 7 | Haptics, settings |
| 8 | Testing, polish |

---

## Key Code: uinput Setup (Python)

```python
import uinput

device = uinput.Device([
    uinput.BTN_A, uinput.BTN_B, uinput.BTN_X, uinput.BTN_Y,
    uinput.BTN_TL, uinput.BTN_TR,
    uinput.ABS_X + (-32768, 32767, 0, 128),
    uinput.ABS_Y + (-32768, 32767, 0, 128),
])

# Send button press
device.emit(uinput.BTN_A, 1)
device.emit(uinput.BTN_A, 0)

# Send analog value
device.emit(uinput.ABS_X, 15000)
```

## Key Code: UDP Server (Python)

```python
import socket

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('0.0.0.0', 5006))

while True:
    data, addr = sock.recvfrom(1024)
    packet = json.loads(data)
    process_input(packet)
```

## Key Code: ADB Forward (Shell)

```bash
adb forward tcp:5005 tcp:5005
```

---

## Required Permissions (Android)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

## Flutter Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  udp: ^5.0.3
  vibration: ^1.8.4
  shared_preferences: ^2.2.2
```

## Python Dependencies (requirements.txt)
```
python-uinput
python-evdev
```

---

## Build Instructions

### Desktop Daemon (Linux):
```bash
sudo pip install uinput evdev
python pulsedad_daemon.py
```

### Mobile App:
```bash
flutter pub get
flutter run
```

### Setup:
```bash
# Enable ADB on phone
# Connect via USB
adb forward tcp:5005 tcp:5005
# Run daemon
python pulsedad_daemon.py --mode=usb
```
