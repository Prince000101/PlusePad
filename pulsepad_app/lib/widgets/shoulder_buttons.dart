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
        decoration: BoxDecoration(
          color: isPressed
              ? const Color(0xFF6366F1)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPressed
                ? const Color(0xFF6366F1)
                : const Color(0xFF334155),
            width: 1.5,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPressed ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
