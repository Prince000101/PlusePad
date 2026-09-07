import 'dart:convert';

import '../services/protocol.dart' as p;

/// A single control placed on the (landscape) custom layout canvas.
///
/// Positions are stored as fractions of the screen (0.0 - 1.0) so the same
/// layout scales across screen sizes. `x`,`y` are the centre of the control;
/// `w`,`h` are its size as fractions of the screen width/height.
class ControlSlot {
  final String id;
  final String kind; // 'button' | 'dpad' | 'stick' | 'face'
  double x;
  double y;
  double w;
  double h;
  String label;
  String action;

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

  /// A fresh id for a copy (keeps duplicates from colliding in the editor).
  ControlSlot.clone(ControlSlot o)
      : id = 'c${DateTime.now().microsecondsSinceEpoch}',
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
        id: j['id'] as String? ?? 'c${DateTime.now().microsecondsSinceEpoch}',
        kind: j['kind'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        label: j['label'] as String? ?? '',
        action: j['action'] as String? ?? '',
      );
}

/// What a custom **button** slot fires over the wire. Stored in
/// [ControlSlot.action] as a namespaced string (`pad:A`, `key:W`,
/// `mouse:LMB`) so a gamepad `A` can never collide with the keyboard `A`.
///
/// Non-button slots keep a plain category string instead
/// ('DPAD', 'Y/B/A/X', 'LX/LY', 'RX/RY').
enum SlotActionType { pad, key, mouse }

class SlotAction {
  final SlotActionType type;
  final String name;

  const SlotAction(this.type, this.name);

  String get wire => '${type.name}:$name';

  static const _mouseNames = {'LMB', 'RMB', 'MMB'};

  /// Protocol pad wire names (pc/pulsepad/protocol.py).
  static const _padWireNames = {
    'A', 'B', 'X', 'Y', 'SELECT', 'START',
    'L1', 'R1', 'L2', 'R2', 'L3', 'R3',
    'DPAD_UP', 'DPAD_DOWN', 'DPAD_LEFT', 'DPAD_RIGHT',
  };

  /// Legacy v1 labels that don't match protocol names.
  static const Map<String, String> _padAliases = {
    'LT': 'L2',
    'LB': 'L1',
    'RT': 'R2',
    'RB': 'R1',
  };

  /// Round-trips whatever is stored: namespaced wire strings AND legacy
  /// plain names from v1 layouts ('A', 'W', 'LMB', ...).
  static SlotAction parse(String raw) {
    final i = raw.indexOf(':');
    if (i > 0) {
      final prefix = raw.substring(0, i);
      for (final t in SlotActionType.values) {
        if (t.name == prefix) {
          final name = raw.substring(i + 1);
          if (name.isNotEmpty) return SlotAction(t, name);
        }
      }
    }
    return classify(raw);
  }

  /// Infer the wire target for a legacy plain action string.
  ///
  /// 'A' is ambiguous (gamepad face button AND keyboard key): prefer the
  /// gamepad meaning, since touch custom layouts are overwhelmingly gamepad.
  static SlotAction classify(String raw) {
    if (_mouseNames.contains(raw)) return SlotAction(SlotActionType.mouse, raw);
    final alias = _padAliases[raw];
    if (alias != null) return SlotAction(SlotActionType.pad, alias);
    if (_padWireNames.contains(raw)) return SlotAction(SlotActionType.pad, raw);
    if (p.kKeys.contains(raw)) return SlotAction(SlotActionType.key, raw);
    return SlotAction(SlotActionType.pad, raw);
  }
}

/// A user-customised controller layout: an ordered list of [ControlSlot]s.
class CustomLayout {
  static const String defaultName = 'My Custom';

  final String id;
  String name;
  List<ControlSlot> slots;

  CustomLayout({required this.id, required this.name, required this.slots});

  static String newId() => 'lay${DateTime.now().microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  factory CustomLayout.fromJson(Map<String, dynamic> j) => CustomLayout(
        id: j['id'] as String? ?? CustomLayout.newId(),
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