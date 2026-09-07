import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// PS2 face pad: ▲ ● ✕ ■ laid out like a D-pad cross — but as four large
/// circular buttons (no +/-shaped backing bars sitting behind the glyph rings),
/// so the circles and the face they sit on always line up.
///
/// Identical input model to [DPad]:
///  * **Tap** — press a single face button to hold it (▲ top, ● right,
///    ✕ bottom, ■ left).
///  * **Glide / flick** — keep your finger down and slide across the pad;
///    the held button follows the finger so a flick from ■ to ▲ registers ▲.
/// Each button lights up on its own (only the button under the finger).
class FacePad extends StatefulWidget {
  /// Callback with the controller button name (Y/B/A/X) and pressed state.
  final void Function(String button, bool pressed) onChanged;
  final double size;

  const FacePad({super.key, required this.onChanged, this.size = 150});

  @override
  State<FacePad> createState() => _FacePadState();
}

class _FacePadState extends State<FacePad> {
  static const _buttons = [
    ('Y', '▲'), // top
    ('B', '●'), // right
    ('A', '✕'), // bottom
    ('X', '■'), // left
  ];

  static const _colors = {
    'Y': Color(0xFF35C24C), // triangle green
    'B': Color(0xFFE8484C), // circle red
    'A': Color(0xFF3A7BD5), // cross blue
    'X': Color(0xFFE8578F), // square pink
  };

  /// Button currently held by each active pointer (id -> button, or '' while
  /// the pointer sits in the centre gap).
  final Map<int, String> _pointerArm = {};
  final Set<String> _held = {};

  void _press(String b) {
    if (b.isEmpty || _held.contains(b)) return;
    setState(() => _held.add(b));
    widget.onChanged(b, true);
  }

  void _release(String b) {
    if (b.isEmpty || !_held.contains(b)) return;
    setState(() => _held.remove(b));
    widget.onChanged(b, false);
  }

  /// Maps a local offset (origin = centre) to a button, '' for the centre gap.
  String _buttonAt(Size size, Offset local) {
    final c = Offset(size.width / 2, size.height / 2);
    final off = local - c;
    final arm = size.width / 3;
    final half = arm * 0.5;
    final ax = off.dx.abs(), ay = off.dy.abs();
    if (ax < half && ay < half) return '';
    if (ay >= ax) return off.dy < 0 ? 'Y' : 'A'; // ▲ / ✕
    return off.dx < 0 ? 'X' : 'B'; // ■ / ●
  }

  void _sync(int pointer, String b) {
    final prev = _pointerArm[pointer];
    if (prev == b) return;
    _pointerArm[pointer] = b;
    if (prev != null && prev.isNotEmpty && !_pointerArm.containsValue(prev)) {
      _release(prev);
    }
    if (b.isNotEmpty && !_held.contains(b)) _press(b);
  }

  void _removePointer(int pointer) {
    final b = _pointerArm.remove(pointer);
    if (b != null && b.isNotEmpty && !_pointerArm.containsValue(b)) {
      _release(b);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final arm = widget.size / 3;
    final lit = _held.isNotEmpty;
    final button = arm * 0.94;
    final bbox = arm * 1.0;

    Widget seat(String b) {
      final isActive = _held.contains(b);
      final glyph = _buttons.firstWhere((x) => x.$1 == b).$2;
      return IgnorePointer(
        child: Center(
          child: Container(
            width: button,
            height: button,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _colors[b] : AppTheme.surfaceBright,
              border: Border.all(
                color: isActive ? Colors.white : AppTheme.hairline,
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                          color: _colors[b]!.withOpacity(0.45),
                          blurRadius: button * 0.28,
                          spreadRadius: button * 0.06)
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              glyph,
              style: TextStyle(
                color: isActive ? Colors.white : _colors[b],
                fontWeight: FontWeight.w900,
                fontSize: button * 0.5,
                height: 1,
              ),
            ),
          ),
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _sync(e.pointer, _buttonAt(Size(widget.size, widget.size), e.localPosition));
      },
      onPointerMove: (e) {
        if (_pointerArm.containsKey(e.pointer)) {
          _sync(e.pointer,
              _buttonAt(Size(widget.size, widget.size), e.localPosition));
        }
      },
      onPointerUp: (e) {
        _removePointer(e.pointer);
      },
      onPointerCancel: (e) {
        _removePointer(e.pointer);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: lit ? AppTheme.accent : AppTheme.hairline,
            width: lit ? 1.4 : 1.2,
          ),
        ),
        child: Stack(
          children: [
            // Four big circular buttons in a compass layout, no cross bar.
            Positioned(
                left: arm,
                top: 0,
                child: SizedBox(width: bbox, height: bbox, child: seat('Y')),
            ),
            Positioned(
                left: arm,
                bottom: 0,
                child: SizedBox(width: bbox, height: bbox, child: seat('A'))),
            Positioned(
                left: 0,
                top: arm,
                child: SizedBox(width: bbox, height: bbox, child: seat('X'))),
            Positioned(
                right: 0,
                top: arm,
                child: SizedBox(width: bbox, height: bbox, child: seat('B'))),
            // Neutral centre hub (the glide gap).
            Center(
              child: Container(
                width: arm * 0.42,
                height: arm * 0.42,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBright,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: lit ? AppTheme.accent : AppTheme.hairline,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
