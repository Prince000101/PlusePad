enum ConnectionMode { usb, wifi }
enum ConnectionStatus { disconnected, connecting, connected, error }
enum ControllerLayout { gamepad, psp, ps5, mouse, keyboard }

class GamepadPacket {
  final int timestamp;
  final Map<String, int> buttons;
  final Map<String, double> axes;

  GamepadPacket({required this.timestamp, required this.buttons, required this.axes});

  Map<String, dynamic> toJson() => {
    'type': 'GAMEPAD',
    'timestamp': timestamp,
    'buttons': buttons,
    'axes': axes,
  };
}

class MousePacket {
  final int timestamp;
  final double dx;
  final double dy;
  final Map<String, int> buttons;

  MousePacket({required this.timestamp, required this.dx, required this.dy, required this.buttons});

  Map<String, dynamic> toJson() => {
    'type': 'MOUSE',
    'timestamp': timestamp,
    'dx': dx,
    'dy': dy,
    'buttons': buttons,
  };
}

class KeyboardPacket {
  final int timestamp;
  final String key;
  final int state;

  KeyboardPacket({required this.timestamp, required this.key, required this.state});

  Map<String, dynamic> toJson() => {
    'type': 'KEYBOARD',
    'timestamp': timestamp,
    'key': key,
    'state': state,
  };
}

class HapticPacket {
  final int duration;
  final double intensity;

  HapticPacket({required this.duration, required this.intensity});

  Map<String, dynamic> toJson() => {
    'type': 'HAPTIC',
    'duration': duration,
    'intensity': intensity,
  };
}