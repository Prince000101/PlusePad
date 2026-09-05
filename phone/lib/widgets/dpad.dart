import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Classic cross-shaped D-pad. Four digital directions; callbacks report
/// press/release so the caller can toggle the corresponding DPAD_* flags.
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

  void _press(String dir) {
    if (_pressed.contains(dir)) return;
    setState(() => _pressed.add(dir));
    widget.onChanged(dir, true);
  }

  void _release(String dir) {
    if (!_pressed.remove(dir)) return;
    setState(() {});
    widget.onChanged(dir, false);
  }

  @override
  Widget build(BuildContext context) {
    final arm = widget.size / 3;
    final pressingAny = _pressed.isNotEmpty;

    Widget hitZone(String dir) {
      final isActive = _pressed.contains(dir);
      final iconColor =
          isActive ? AppTheme.accent : AppTheme.textSecondary;
      final icon = _dirs.firstWhere((d) => d.$1 == dir).$2;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(dir),
        onTapUp: (_) => _release(dir),
        onTapCancel: () => _release(dir),
        child: Container(
          width: arm,
          height: arm,
          alignment: Alignment.center,
          child: Container(
            width: arm * 0.72,
            height: arm * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTheme.accentAt(0.22)
                  : Colors.transparent,
              border: Border.all(
                color: isActive ? AppTheme.accent : Colors.transparent,
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: arm * 0.5, color: iconColor),
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: pressingAny ? AppTheme.accent : AppTheme.hairline,
          width: pressingAny ? 1.4 : 1.2,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _CrossPainter(
                armWidth: arm * 1.08,
                baseColor: AppTheme.surfaceBright,
                litColor: AppTheme.accent,
                pressed: _pressed,
              ),
            ),
          ),
          Positioned(left: arm, top: 0, child: hitZone('DPAD_UP')),
          Positioned(left: arm, bottom: 0, child: hitZone('DPAD_DOWN')),
          Positioned(left: 0, top: arm, child: hitZone('DPAD_LEFT')),
          Positioned(right: 0, top: arm, child: hitZone('DPAD_RIGHT')),
          Center(
            child: Container(
              width: arm * 0.5,
              height: arm * 0.5,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBright,
                shape: BoxShape.circle,
                border: Border.all(
                  color: pressingAny ? AppTheme.accent : AppTheme.hairline,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final double armWidth;
  final Color baseColor;
  final Color litColor;
  final Set<String> pressed;

  _CrossPainter({
    required this.armWidth,
    required this.baseColor,
    required this.litColor,
    required this.pressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    const edgeInset = 3.0;

    final vRect = (
      Rect.fromLTWH(c - armWidth / 2, edgeInset, armWidth, size.height - edgeInset * 2),
      pressed.contains('DPAD_UP') || pressed.contains('DPAD_DOWN'),
    );
    final hRect = (
      Rect.fromLTWH(edgeInset, c - armWidth / 2, size.width - edgeInset * 2, armWidth),
      pressed.contains('DPAD_LEFT') || pressed.contains('DPAD_RIGHT'),
    );

    _drawArm(canvas, vRect);
    _drawArm(canvas, hRect);
  }

  void _drawArm(Canvas canvas, (Rect, bool) arm) {
    final (rect, active) = arm;
    final paint = Paint()
      ..color = active ? litColor : baseColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), paint);

    final rim = Paint()
      ..color = active ? Color.lerp(litColor, Colors.white, 0.3)! : AppTheme.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(0.75), const Radius.circular(7)), rim);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.pressed != pressed;
}