import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// L1 / L2 / R2 / R1 shoulder buttons.
class ShoulderButtons extends StatefulWidget {
  final void Function(String button) onPressed;
  final void Function(String button) onReleased;
  final bool horizontal;

  const ShoulderButtons({
    super.key,
    required this.onPressed,
    required this.onReleased,
    this.horizontal = false,
  });

  @override
  State<ShoulderButtons> createState() => _ShoulderButtonsState();
}

class _ShoulderButtonsState extends State<ShoulderButtons> {
  final Set<String> _pressed = {};

  void _down(String b) {
    _pressed.add(b);
    setState(() {});
    widget.onPressed(b);
  }

  void _up(String b) {
    _pressed.remove(b);
    setState(() {});
    widget.onReleased(b);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.horizontal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [_btn('L1'), _btn('L2'), _btn('R2'), _btn('R1')],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [_btn('L1'), const SizedBox(width: 12), _btn('L2')]),
          Row(children: [_btn('R2'), const SizedBox(width: 12), _btn('R1')]),
        ],
      ),
    );
  }

  Widget _btn(String label) {
    final isPressed = _pressed.contains(label);
    // L buttons tilt top-left, R buttons tilt top-right (subtle)
    final alignTopLeft = label.startsWith('L');
    final gradient = LinearGradient(
      begin: alignTopLeft ? Alignment.topLeft : Alignment.topRight,
      end: Alignment.bottomCenter,
      colors: isPressed
          ? [AppTheme.accentB, AppTheme.accentA]
          : [const Color(0xFF2C3A54), const Color(0xFF151C2E)],
    );

    return GestureDetector(
      onTapDown: (_) => _down(label),
      onTapUp: (_) => _up(label),
      onTapCancel: () => _up(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 58,
        height: 46,
        transform: Matrix4.translationValues(0, isPressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: gradient,
          border: Border.all(
            color: isPressed ? AppTheme.accentB : AppTheme.hairline,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPressed
                  ? AppTheme.accentA.withOpacity(0.55)
                  : Colors.black.withOpacity(0.45),
              blurRadius: isPressed ? 16 : 6,
              spreadRadius: isPressed ? 2 : 0,
              offset: Offset(0, isPressed ? 1 : 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label.startsWith('L') ? Icons.chevron_left : Icons.chevron_right,
              size: 12,
              color: isPressed ? Colors.white : Colors.white54,
            ),
            Text(
              label,
              style: TextStyle(
                color: isPressed ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
