import 'package:flutter/material.dart';

/// Face buttons (Y / X / B / A) laid out like a real gamepad. Manages its own
/// transient press state purely for visual feedback; the authoritative state
/// lives in the shared ControllerState exposed via the onPressed/onReleased
/// callbacks.
class ActionButtons extends StatefulWidget {
  final void Function(String button) onPressed;
  final void Function(String button) onReleased;

  const ActionButtons({
    super.key,
    required this.onPressed,
    required this.onReleased,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
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
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 10, child: _btn('Y', const Color(0xFF22C55E))),
          Positioned(
              left: 20, bottom: 40, child: _btn('X', const Color(0xFF3B82F6))),
          Positioned(
              right: 20, bottom: 40, child: _btn('B', const Color(0xFFEF4444))),
          Positioned(right: 10, top: 50, child: _btn('A', const Color(0xFFF59E0B))),
        ],
      ),
    );
  }

  Widget _btn(String label, Color color) {
    final isPressed = _pressed.contains(label);
    return GestureDetector(
      onTapDown: (_) => _down(label),
      onTapUp: (_) => _up(label),
      onTapCancel: () => _up(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 40),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isPressed ? color : color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 3),
                ]
              : [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1),
                ],
        ),
        child: Center(
          child: Text(
            label,
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
