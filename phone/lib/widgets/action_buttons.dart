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
          Positioned(top: 8, child: _btn('Y', const Color(0xFF22C55E))),
          Positioned(
              left: 22, bottom: 38, child: _btn('X', const Color(0xFF3B82F6))),
          Positioned(
              right: 22, bottom: 38, child: _btn('B', const Color(0xFFEF4444))),
          Positioned(right: 8, top: 52, child: _btn('A', const Color(0xFFF59E0B))),
        ],
      ),
    );
  }

  Widget _btn(String label, Color color) {
    final isPressed = _pressed.contains(label);
    final light = Color.lerp(color, Colors.white, 0.35)!;
    return GestureDetector(
      onTapDown: (_) => _down(label),
      onTapUp: (_) => _up(label),
      onTapCancel: () => _up(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 56,
        height: 56,
        transform: Matrix4.translationValues(0, isPressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPressed
                ? [light, color]
                : [Colors.white.withOpacity(0.10), color.withOpacity(0.85)],
          ),
          border: Border.all(
              color: isPressed ? light : color.withOpacity(0.9), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isPressed ? 0.7 : 0.4),
              blurRadius: isPressed ? 22 : 10,
              spreadRadius: isPressed ? 4 : 1,
              offset: isPressed ? Offset.zero : const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 6,
              offset: Offset(0, isPressed ? 0 : 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPressed ? Colors.white : Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w800,
              fontSize: 20,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          ),
        ),
      ),
    );
  }
}
