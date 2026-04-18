class InputPacket {
  final int timestamp;
  final Map<String, int> buttons;
  final Map<String, double> axes;

  InputPacket({
    required this.timestamp,
    required this.buttons,
    required this.axes,
  });

  Map<String, dynamic> toJson() => {
    'type': 'INPUT',
    'timestamp': timestamp,
    'buttons': buttons,
    'axes': axes,
  };

  factory InputPacket.fromJson(Map<String, dynamic> json) {
    return InputPacket(
      timestamp: json['timestamp'] as int,
      buttons: Map<String, int>.from(json['buttons'] ?? {}),
      axes: Map<String, double>.from(json['axes'] ?? {}),
    );
  }
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

enum ConnectionMode { usb, wifi }

enum ConnectionStatus { disconnected, connecting, connected, error }