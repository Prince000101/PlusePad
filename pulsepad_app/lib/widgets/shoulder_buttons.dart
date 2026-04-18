import 'package:flutter/material.dart';

class ShoulderButtons extends StatelessWidget {
  final Map<String, int> buttons;
  final Function(String) onPressed;
  final Function(String) onReleased;
  final bool horizontal;

  const ShoulderButtons({
    super.key,
    required this.buttons,
    required this.onPressed,
    required this.onReleased,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return horizontal
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildButton('L1', 'L1', 0),
              _buildButton('L2', 'L2', 1),
              _buildButton('R2', 'R2', 2),
              _buildButton('R1', 'R1', 3),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                _buildButton('L1', 'L1', 0),
                const SizedBox(width: 12),
                _buildButton('L2', 'L2', 1),
              ]),
              Row(children: [
                _buildButton('R2', 'R2', 2),
                const SizedBox(width: 12),
                _buildButton('R1', 'R1', 3),
              ]),
            ],
          );
  }

  Widget _buildButton(String label, String display, int index) {
    final isPressed = buttons[label] == 1;
    return GestureDetector(
      onTapDown: (_) => onPressed(label),
      onTapUp: (_) => onReleased(label),
      onTapCancel: () => onReleased(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
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
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            display,
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