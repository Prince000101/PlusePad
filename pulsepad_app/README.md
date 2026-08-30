# PulsePad (Android App)

The Flutter controller app that runs on your Android phone and streams inputs
over a WiFi/LAN or USB (adb-reverse) connection to the PulsePad daemon running
on a PC.

See the [root README](../README.md) for the full project, install instructions
and the binary protocol spec.

## Layout

```
lib/
  services/protocol.dart         byte-compatible mirror of the daemon protocol
  services/connection_manager.dart  UDP/TCP transport, discovery, reconnect, latency
  models/controller_state.dart   full gamepad state + encode
  screens/controller_screen.dart gamepad/PSP/PS5/mouse/keyboard layouts
  screens/connection_screen.dart start + auto-discover + connect
  widgets/                       dpad, analog stick, action/shoulder buttons
```

## Run

```bash
flutter pub get
flutter run             # on a connected device
# or
flutter build apk --release
```
