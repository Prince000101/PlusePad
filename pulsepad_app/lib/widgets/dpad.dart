import 'package:flutter/material.dart';

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
    const crossColor = Color(0xFF273449);

    Widget hitZone(String dir) {
      final isActive = _pressed.contains(dir);
      final iconColor = isActive ? const Color(0xFF6366F1) : Colors.white54;
      final icon = _dirs.firstWhere((d) => d.$1 == dir).$2;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(dir),
        onTapUp: (_) => _release(dir),
        onTapCancel: () => _release(dir),
        child: Container(
          width: arm,
          height: arm,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Icon(icon, size: arm * 0.5, color: iconColor),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF334155), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _CrossPainter(armWidth: arm, color: crossColor,
                  active: const Color(0xFF6366F1), pressed: _pressed),
            ),
          ),
          Positioned(left: arm, top: 0,
              child: hitZone('DPAD_UP')),
          Positioned(left: arm, bottom: 0,
              child: hitZone('DPAD_DOWN')),
          Positioned(left: 0, top: arm,
              child: hitZone('DPAD_LEFT')),
          Positioned(right: 0, top: arm,
              child: hitZone('DPAD_RIGHT')),
          Center(
            child: Container(
              width: arm * 0.5, height: arm * 0.5,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B), shape: BoxShape.circle,
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
  final Color color;
  final Color active;
  final Set<String> pressed;

  _CrossPainter(
      {required this.armWidth,
      required this.color,
      required this.active,
      required this.pressed});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const r = Radius.circular(6);

    // Vertical arm
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(c - armWidth / 2, 0, armWidth, size.height), r),
        paint);
    // Horizontal arm
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, c - armWidth / 2, size.width, armWidth), r),
        paint);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) =>
      old.pressed != pressed || old.color != color;
}
