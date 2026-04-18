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
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: _buildButton('Y', const Color(0xFF22C55E), 'Y'),
          ),
          Positioned(
            bottom: 15,
            left: 0,
            child: _buildButton('X', const Color(0xFF3B82F6), 'X'),
          ),
          Positioned(
            bottom: 15,
            right: 0,
            child: _buildButton('B', const Color(0xFFEF4444), 'B'),
          ),
          Positioned(
            right: 25,
            top: 30,
            child: _buildButton('A', const Color(0xFFF59E0B), 'A'),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color, String display) {
    final isPressed = buttons[label] == 1;
    return GestureDetector(
      onTapDown: (_) => onPressed(label),
      onTapUp: (_) => onReleased(label),
      onTapCancel: () => onReleased(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: isPressed ? color : color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(isPressed ? 1 : 0.5),
            width: 2,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(color: color.withOpacity(0.6), blurRadius: 20, spreadRadius: 2),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            display,
            style: TextStyle(
              color: isPressed ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}