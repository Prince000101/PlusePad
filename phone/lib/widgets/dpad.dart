import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Classic cross-shaped D-pad that supports two input styles:
///
///  * **Tap** — press one of the four directional arms to hold it.
///  * **Glide / flick** — keep your finger on the pad and slide across the
///    cross; the held direction follows the finger, so a quick flick from
///    LEFT to UP registers UP without lifting. Only the arm under the finger
///    lights up at a time (each direction is its own lit region).
class DPad extends StatefulWidget {
  final void Function(String direction, bool pressed) onChanged;
  final double size;

  const DPad({super.key, required this.onChanged, this.size = 140});

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  static const _dirs = [
    ('DPAD_UP', Icons.keyboard_arrow_up),
    ('DPAD_DOWN', Icons.keyboard_arrow_down),
    ('DPAD_LEFT', Icons.keyboard_arrow_left),
    ('DPAD_RIGHT', Icons.keyboard_arrow_right),
  ];

  final Set<String> _pressed = {};

  /// True while the user has a finger down on the pad (drives glide tracking).
  bool _pointing = false;

  void _press(String dir) {
    if (dir.isEmpty || _pressed.contains(dir)) return;
    for (final held in _pressed.toList()) {
      if (held != dir) {
        _pressed.remove(held);
        widget.onChanged(held, false);
      }
    }
    setState(() => _pressed.add(dir));
    widget.onChanged(dir, true);
  }

  void _releaseAll() {
    if (_pressed.isEmpty) return;
    for (final dir in _pressed.toList()) {
      setState(() => _pressed.remove(dir));
      widget.onChanged(dir, false);
    }
  }

  /// Maps a local [Offset] (origin = centre of the pad) to a direction, or ''
  /// for the central dead-zone / diagonals.
  String _dirAt(Size size, Offset local) {
    final c = Offset(size.width / 2, size.height / 2);
    final off = local - c;
    final arm = size.width / 3;
    final half = arm * 0.5;
    final ax = off.dx.abs(), ay = off.dy.abs();
    if (ax < half && ay < half) return ''; // centre gap
    if (ay >= ax) return off.dy < 0 ? 'DPAD_UP' : 'DPAD_DOWN';
    return off.dx < 0 ? 'DPAD_LEFT' : 'DPAD_RIGHT';
  }

  void _handlePoint(Offset local, Size size) {
    _press(_dirAt(size, local));
  }

  @override
  Widget build(BuildContext context) {
    final arm = widget.size / 3;

    Widget arrow(String dir) {
      final isActive = _pressed.contains(dir);
      final icon = _dirs.firstWhere((d) => d.$1 == dir).$2;
      return IgnorePointer(
        child: Icon(
          icon,
          size: arm * 0.5,
          color: isActive ? Colors.white : AppTheme.textSecondary,
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _pointing = true;
        _handlePoint(e.localPosition, Size(widget.size, widget.size));
      },
      onPointerMove: (e) {
        if (_pointing) {
          _handlePoint(e.localPosition, Size(widget.size, widget.size));
        }
      },
      onPointerUp: (_) {
        _pointing = false;
        _releaseAll();
      },
      onPointerCancel: (_) {
        _pointing = false;
        _releaseAll();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: _pressed.isEmpty ? AppTheme.hairline : AppTheme.accent,
            width: _pressed.isEmpty ? 1.2 : 1.4,
          ),
        ),
        child: Stack(
          children: [
            // Lit cross arms, drawn individually so each direction lights
            // on its own (LEFT no longer lights RIGHT).
            Positioned(
              left: arm - arm * 0.5,
              top: 0,
              child: _armRect(
                  'DPAD_UP',
                  Size(arm, widget.size - arm * 0.5),
                  Alignment.bottomCenter),
            ),
            Positioned(
              left: arm - arm * 0.5,
              bottom: 0,
              child: _armRect(
                  'DPAD_DOWN',
                  Size(arm, widget.size - arm * 0.5),
                  Alignment.topCenter),
            ),
            Positioned(
              left: 0,
              top: arm - arm * 0.5,
              child: _armRect(
                  'DPAD_LEFT',
                  Size(widget.size - arm * 0.5, arm),
                  Alignment.centerRight),
            ),
            Positioned(
              right: 0,
              top: arm - arm * 0.5,
              child: _armRect(
                  'DPAD_RIGHT',
                  Size(widget.size - arm * 0.5, arm),
                  Alignment.centerLeft),
            ),
            // Directional arrows.
            Positioned(
                left: arm,
                top: 0,
                child: SizedBox(
                    width: arm,
                    height: arm,
                    child: Center(child: arrow('DPAD_UP')))),
            Positioned(
                left: arm,
                bottom: 0,
                child: SizedBox(
                    width: arm,
                    height: arm,
                    child: Center(child: arrow('DPAD_DOWN')))),
            Positioned(
                left: 0,
                top: arm,
                child: SizedBox(
                    width: arm,
                    height: arm,
                    child: Center(child: arrow('DPAD_LEFT')))),
            Positioned(
                right: 0,
                top: arm,
                child: SizedBox(
                    width: arm,
                    height: arm,
                    child: Center(child: arrow('DPAD_RIGHT')))),
            Center(
              child: Container(
                width: arm * 0.5,
                height: arm * 0.5,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBright,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _pressed.isEmpty ? AppTheme.hairline : AppTheme.accent,
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

  Widget _armRect(String dir, Size size, Alignment align) {
    final isActive = _pressed.contains(dir);
    return IgnorePointer(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Align(
          alignment: align,
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accent : AppTheme.surfaceBright,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? Color.lerp(AppTheme.accent, Colors.white, 0.3)!
                    : AppTheme.hairline,
                width: isActive ? 1.4 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
