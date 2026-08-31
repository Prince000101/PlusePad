import 'dart:convert';

/// A single control placed on the (landscape) custom layout canvas.
///
/// Positions are stored as fractions of the screen (0.0 - 1.0) so the same
/// layout scales across screen sizes. `x`,`y` are the centre of the control;
/// `w`,`h` are its size as fractions of the screen width/height.
class ControlSlot {
  final String id;
  final String kind; // 'button' | 'dpad' | 'stick'
  double x;
  double y;
  double w;
  double h;
  String label;
  String action; // button name (e.g. 'A', 'LB', 'W', 'SELECT')

  ControlSlot({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.label,
    required this.action,
  });

  ControlSlot.copy(ControlSlot o)
      : id = o.id,
        kind = o.kind,
        x = o.x,
        y = o.y,
        w = o.w,
        h = o.h,
        label = o.label,
        action = o.action;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'label': label,
        'action': action,
      };

  factory ControlSlot.fromJson(Map<String, dynamic> j) => ControlSlot(
        id: j['id'] as String,
        kind: j['kind'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        label: j['label'] as String? ?? '',
        action: j['action'] as String? ?? '',
      );
}

/// A user-customised controller layout: an ordered list of [ControlSlot]s.
class CustomLayout {
  static const String defaultName = 'My Custom';

  String name;
  List<ControlSlot> slots;

  CustomLayout({required this.name, required this.slots});

  Map<String, dynamic> toJson() => {
        'name': name,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  factory CustomLayout.fromJson(Map<String, dynamic> j) => CustomLayout(
        name: j['name'] as String? ?? defaultName,
        slots: (j['slots'] as List<dynamic>? ?? [])
            .map((e) => ControlSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  static CustomLayout? decode(String raw) {
    try {
      return CustomLayout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
