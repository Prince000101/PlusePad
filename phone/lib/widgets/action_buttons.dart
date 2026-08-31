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
    final light = Color.lerp(color, Colors.white, 0.40)!;
    return GestureDetector(
      onTapDown: (_) => _down(label),
      onTapUp: (_) => _up(label),
      onTapCancel: () => _up(label),
      child: AnimatedScale(
        scale: isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPressed
                  ? [light, color]
                  : [light.withOpacity(0.55), color],
            ),
            border: Border.all(
                color: isPressed ? Colors.white70 : light.withOpacity(0.6),
                width: 2),
            boxShadow: [
              // ambient colored glow
              BoxShadow(
                color: color.withOpacity(isPressed ? 0.8 : 0.4),
                blurRadius: isPressed ? 26 : 12,
                spreadRadius: isPressed ? 5 : 1,
                offset: isPressed ? Offset.zero : const Offset(0, 5),
              ),
              // contact shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 6,
                offset: Offset(0, isPressed ? 1 : 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // glossy highlight on top half
              Positioned(
                top: 5,
                child: Container(
                  width: 44,
                  height: 26,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white38, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
