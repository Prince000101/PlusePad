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
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Y button (top)
          Positioned(
            top: 10,
            child: _buildButton('Y', const Color(0xFF22C55E), 'Y'),
          ),
          // X button (bottom left)
          Positioned(
            left: 20,
            bottom: 40,
            child: _buildButton('X', const Color(0xFF3B82F6), 'X'),
          ),
          // B button (bottom right)
          Positioned(
            right: 20,
            bottom: 40,
            child: _buildButton('B', const Color(0xFFEF4444), 'B'),
          ),
          // A button (right)
          Positioned(
            right: 10,
            top: 50,
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
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isPressed ? color : color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 2.5,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            display,
            style: TextStyle(
              color: isPressed ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}