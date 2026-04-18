import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final Map<String, int> buttons;
  final Function(String) onPressed;
  final Function(String) onReleased;

  const ActionButtons({
    super.key,
    required this.buttons,
    required this.onPressed,
    required this.onReleased,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: _buildButton('Y', const Color(0xFF22C55E)),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: _buildButton('X', const Color(0xFF3B82F6)),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildButton('B', const Color(0xFFEF4444)),
          ),
          Positioned(
            right: 20,
            child: _buildButton('A', const Color(0xFFF59E0B)),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color) {
    final isPressed = buttons[label] == 1;
    return GestureDetector(
      onTapDown: (_) => onPressed(label),
      onTapUp: (_) => onReleased(label),
      onTapCancel: () => onReleased(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isPressed ? color : color.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: isPressed
              ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 15)]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPressed ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}