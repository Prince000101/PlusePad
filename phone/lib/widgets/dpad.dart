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

  /// Arm currently held by each active pointer (id -> direction, or '' while
  /// the pointer sits in the centre gap).
  final Map<int, String> _pointerArm = {};
  final Set<String> _held = {};

  void _press(String dir) {
    if (dir.isEmpty || _held.contains(dir)) return;
    setState(() => _held.add(dir));
    widget.onChanged(dir, true);
  }

  void _release(String dir) {
    if (dir.isEmpty || !_held.contains(dir)) return;
    setState(() => _held.remove(dir));
    widget.onChanged(dir, false);
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

  void _sync(int pointer, String dir) {
    final prev = _pointerArm[pointer];
    if (prev == dir) return;
    _pointerArm[pointer] = dir;
    if (prev != null && prev.isNotEmpty && !_pointerArm.containsValue(prev)) {
      _release(prev);
    }
    if (dir.isNotEmpty && !_held.contains(dir)) _press(dir);
  }

  void _removePointer(int pointer) {
    final arm = _pointerArm.remove(pointer);
    if (arm != null && arm.isNotEmpty && !_pointerArm.containsValue(arm)) {
      _release(arm);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final arm = widget.size / 3;
    final lit = _held.isNotEmpty;

    Widget arrow(String dir) {
      final isActive = _held.contains(dir);
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
        _sync(e.pointer, _dirAt(Size(widget.size, widget.size), e.localPosition));
      },
      onPointerMove: (e) {
        if (_pointerArm.containsKey(e.pointer)) {
          _sync(
              e.pointer, _dirAt(Size(widget.size, widget.size), e.localPosition));
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
            // Proper plus-cross: 4 independent arms + shared centre, each arm
            // lights on its own (LEFT no longer lights RIGHT).
            Positioned.fill(
              child: CustomPaint(
                painter: _CrossPainter(
                  arm,
                  baseColor: AppTheme.surfaceBright,
                  litColor: AppTheme.accent,
                  pressed: {..._held},
                ),
              ),
            ),
            // Directional arrows, one per arm.
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

/// Paints the classic plus-cross. The vertical bar is split in half (top arm
/// lights for UP, bottom for DOWN), and the horizontal bar likewise for
/// LEFT/RIGHT, so each direction highlights on its own.
class _CrossPainter extends CustomPainter {
  final double arm;
  final Color baseColor;
  final Color litColor;
  final Set<String> pressed;

  _CrossPainter(this.arm,
      {required this.baseColor,
      required this.litColor,
      required this.pressed});

  @override
  void paint(Canvas canvas, Size size) {
    final armW = arm * 0.9;
    final c = size.width / 2;
    const edge = 4.0;

    const r = RRect.fromRectAndRadius;

    void drawArm(Rect rect, bool active) {
      final paint = Paint()
        ..color = active ? litColor : baseColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          r(rect, const Radius.circular(7)), paint);
      final rim = Paint()
        ..color = active
            ? Color.lerp(litColor, Colors.white, 0.35)!
            : AppTheme.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.4 : 1;
      canvas.drawRRect(
          r(rect.deflate(0.75), const Radius.circular(7)), rim);
    }

    // Centre square lights whenever any direction is held.
    drawArm(Rect.fromLTWH(c - armW / 2, c - armW / 2, armW, armW),
        pressed.isNotEmpty);

    // Vertical top (UP) / bottom (DOWN).
    drawArm(Rect.fromLTWH(c - armW / 2, edge, armW, c - edge),
        pressed.contains('DPAD_UP'));
    drawArm(Rect.fromLTWH(c - armW / 2, c, armW, c - edge),
        pressed.contains('DPAD_DOWN'));

    // Horizontal left (LEFT) / right (RIGHT).
    drawArm(Rect.fromLTWH(edge, c - armW / 2, c - edge, armW),
        pressed.contains('DPAD_LEFT'));
    drawArm(Rect.fromLTWH(c, c - armW / 2, c - edge, armW),
        pressed.contains('DPAD_RIGHT'));
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) =>
      old.pressed != pressed;
}
