import 'package:flutter/material.dart';

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
    final left = Row(
      children: [
        _btn('L1'),
        const SizedBox(width: 12),
        _btn('L2'),
      ],
    );
    final right = Row(
      children: [
        _btn('R2'),
        const SizedBox(width: 12),
        _btn('R1'),
      ],
    );

    return widget.horizontal
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_btn('L1'), _btn('L2'), _btn('R2'), _btn('R1')],
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [left, right],
            ),
          );
  }

  Widget _btn(String label) {
    final isPressed = _pressed.contains(label);
    return GestureDetector(
      onTapDown: (_) => _down(label),
      onTapUp: (_) => _up(label),
      onTapCancel: () => _up(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 56,
        height: 44,
        transform: Matrix4.translationValues(0, isPressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isPressed
                ? [const Color(0xFF818CF8), const Color(0xFF6366F1)]
                : [const Color(0xFF2A3A52), const Color(0xFF1E293B)],
          ),
          border: Border.all(
            color: isPressed
                ? const Color(0xFF818CF8)
                : const Color(0xFF475569),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPressed
                  ? const Color(0xFF6366F1).withOpacity(0.5)
                  : Colors.black.withOpacity(0.4),
              blurRadius: isPressed ? 16 : 6,
              spreadRadius: isPressed ? 2 : 0,
              offset: Offset(0, isPressed ? 0 : 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_vert,
                size: 12,
                color: isPressed ? Colors.white : Colors.white38),
            Text(
              label,
              style: TextStyle(
                color: isPressed ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
