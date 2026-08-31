import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A classic cross-shaped D-pad. Four digital directions; callbacks report
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
      final iconColor = isActive ? Colors.white : Colors.white54;
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
                  ? AppTheme.accentA.withOpacity(0.5)
                  : Colors.transparent,
              boxShadow: isActive ? AppTheme.glow(AppTheme.accentB, opacity: 0.6, blur: 14) : null,
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
        color: const Color(0xFF0A0F20),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.hairline, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 14,
              offset: const Offset(0, 5)),
          BoxShadow(
              color: AppTheme.accentA.withOpacity(pressingAny ? 0.45 : 0.12),
              blurRadius: pressingAny ? 24 : 14,
              spreadRadius: pressingAny ? 3 : 0),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _CrossPainter(
                armWidth: arm * 1.05,
                baseColor: const Color(0xFF1A2337),
                litColor: AppTheme.accentB,
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
                color: const Color(0xFF1A2337),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentA.withOpacity(0.6), width: 1.2),
                boxShadow: pressingAny
                    ? AppTheme.glow(AppTheme.accentB, opacity: 0.5, blur: 12)
                    : null,
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

    // Vertical arm
    Rect vRect =
        Rect.fromLTWH(c - armWidth / 2, edgeInset, armWidth, size.height - edgeInset * 2);
    // Horizontal arm
    Rect hRect =
        Rect.fromLTWH(edgeInset, c - armWidth / 2, size.width - edgeInset * 2, armWidth);

    bool vActive = pressed.contains('DPAD_UP') || pressed.contains('DPAD_DOWN');
    bool hActive = pressed.contains('DPAD_LEFT') || pressed.contains('DPAD_RIGHT');

    _drawArm(canvas, vRect, vActive);
    _drawArm(canvas, hRect, hActive);
  }

  void _drawArm(Canvas canvas, Rect rect, bool active) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: active
            ? [litColor, Color.lerp(litColor, Colors.white, 0.2)!]
            : [const Color(0xFF242F47), baseColor],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // beveled arm with rounded ends
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), paint);

    // top gloss
    final gloss = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white12, Colors.transparent],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), gloss);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.pressed != pressed;
}
