import 'package:flutter/material.dart';

class ShoulderButtons extends StatelessWidget {
  final Map<String, int> buttons;
  final Function(String) onPressed;
  final Function(String) onReleased;

  const ShoulderButtons({
    super.key,
    required this.buttons,
    required this.onPressed,
    required this.onReleased,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildButton('L1', 'L1'),
          _buildButton('L2', 'L2'),
          _buildButton('R2', 'R2'),
          _buildButton('R1', 'R1'),
        ],
      ),
    );
  }

  Widget _buildButton(String label, String display) {
    final isPressed = buttons[label] == 1;
    return GestureDetector(
      onTapDown: (_) => onPressed(label),
      onTapUp: (_) => onReleased(label),
      onTapCancel: () => onReleased(label),
      child: Container(
        width: 70,
        height: 40,
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            display,
            style: TextStyle(
              color: isPressed ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}