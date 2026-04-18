# PulsePad

**Transform your smartphone into a low-latency game controller for your Linux PC.**

PulsePad provides a sub-10ms latency experience matching native hardware controllers. It works by creating a virtual gamepad using Linux `uinput` combined with a Flutter mobile application and a Python desktop daemon.

---

## 🚀 Features

- **Ultra-Low Latency:** <5ms via USB (ADB) and <15ms via Wi-Fi (UDP).
- **Plug-and-Play Linux Support:** Creates a virtual gamepad recognized by Steam, Emulators, and native Linux games.
- **Dual Connection Modes:** Choose between ultra-stable USB (recommended) or convenient Wi-Fi.
- **Standard Gamepad Layout:** Supports A, B, X, Y buttons, L1/R1/L2/R2 triggers, and Analog stick input.
- **Haptic Feedback:** Real-time vibration support for an immersive experience.
- **Real-time Latency Display:** Monitor your connection speed in the app.

---

## 🛠️ System Architecture

```text
┌─────────────────┐        USB/WiFi        ┌─────────────────┐
│   Flutter App   │ ────────────────────── │  Python Daemon  │
│   (Android)     │   tcp:5005 / udp:5006  │   (Linux PC)    │
└────────┬────────┘                        └────────┬────────┘
         │                                          │
         │  Input packets                           │  uinput events
         │  (JSON/bytes)                            │  (/dev/input)
         └──────────────────────────────────────────┘
                            ↓
                   ┌─────────────────┐
                   │  Virtual Gamepad│
                   │  /dev/input/js0 │
                   └─────────────────┘
```

---

## 📋 Requirements

### Desktop (Linux)
- Python 3.x
- `python-uinput`
- `python-evdev`
- `adb` (for USB mode)

### Mobile (Android)
- Android Smartphone
- USB debugging enabled (for USB mode)

---

## ⚙️ Installation & Setup

### 1. Setup the Desktop Daemon (Linux PC)

Install the required Python dependencies:
```bash
# You might need system-level dependencies for uinput
sudo apt-get install python3-pip
sudo pip3 install uinput evdev
```

*Note: The daemon requires `sudo` privileges to create virtual `uinput` devices.*

Navigate to the `daemon` directory and run the daemon:
```bash
cd daemon
sudo python3 pulsedad_daemon.py
```

### 2. Setup the Mobile App (Flutter)

Connect your Android phone to your PC via USB and enable USB Debugging.

```bash
flutter pub get
flutter run
```

### 3. Connect

**Using USB (Recommended for minimum latency):**
1. Ensure your phone is connected and ADB is authorized.
2. Run the ADB port forwarding command on your PC:
   ```bash
   adb forward tcp:5005 tcp:5005
   ```
3. Open the PulsePad app, select "USB" and tap Connect.

**Using Wi-Fi:**
1. Connect both your PC and Phone to the same Wi-Fi network.
2. Open the PulsePad app, input your PC's local IP Address.
3. Select "Wi-Fi" and tap Connect.

---

## 🎮 Virtual Controller Mapping

PulsePad maps directly to standard Linux gamepad inputs (`js0`):

| Button | Code (uinput) | Type |
|--------|---------------|------|
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

---

## 🔮 Future Scope
- Dual analog sticks support
- Gyroscope (Motion Controls) support
- Custom controller profiles
- Multiplayer mode (multiple phones connected to one PC)
- Binary protocol optimization for even lower latency

## 📄 License
This project is open-source. Feel free to modify and distribute.
