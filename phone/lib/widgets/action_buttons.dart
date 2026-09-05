import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Face buttons in the classic diamond: top=Y, left=X, right=B, bottom=A.
///
/// In [ps2] mode the pads render the PlayStation symbols (▲ ● ✕ ■) in their
/// PS2 colors — the same identity the PC "Gamepad tester" panel uses, so a
/// pressed button lights the matching tester button 1:1. Otherwise plain
/// letter labels (used by the custom-layout editor).
class ActionButtons extends StatefulWidget {
  final void Function(String button) onPressed;
  final void Function(String button) onReleased;
  final double size;
  final bool ps2;

  const ActionButtons({
    super.key,
    required this.onPressed,
    required this.onReleased,
    this.size = 170,
    this.ps2 = false,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
  final Set<String> _pressed = {};

  /// Diameter of each face button (slightly larger for a PS-style grip).
  double get _d => widget.size / 2.7;

  /// Alignment of each face button within the diamond (x, y in -1..1).
  static const _pos = {
    'Y': Alignment(0.0, -0.78), // triangle, top
    'B': Alignment(0.78, 0.0), // circle, right
    'A': Alignment(0.0, 0.78), // cross, bottom
    'X': Alignment(-0.78, 0.0), // square, left
  };

  static const _ps2Glyph = {'Y': '▲', 'B': '●', 'A': '✕', 'X': '■'};
  static const _ps2Color = {
    'Y': Color(0xFF35C24C), // triangle green
    'B': Color(0xFFE8484C), // circle red
    'A': Color(0xFF3A7BD5), // cross blue
    'X': Color(0xFFE8578F), // square pink
  };

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
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final e in _pos.entries)
            Positioned.fill(
              child: Align(
                alignment: e.value,
                child: _btn(e.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _btn(String label) {
    final isPressed = _pressed.contains(label);
    final Color lit = _ps2Color[label] ?? AppTheme.accent;
    final Color fill =
        isPressed ? (widget.ps2 ? lit : AppTheme.accentAt(0.22)) : AppTheme.surfaceAlt;
    final Color ring =
        isPressed ? (widget.ps2 ? lit : AppTheme.accent) : AppTheme.hairline;
    final String glyph = widget.ps2 ? (_ps2Glyph[label] ?? label) : label;
    final Color glyphColor =
        isPressed ? (widget.ps2 ? Colors.white : AppTheme.accent) : AppTheme.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(label),
      onTapUp: (_) => _up(label),
      onTapCancel: () => _up(label),
      child: AnimatedScale(
        scale: isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 60),
        child: Container(
          width: _d,
          height: _d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(
              color: ring,
              width: isPressed ? 2.2 : 1.4,
            ),
            boxShadow: isPressed
                ? [
                    BoxShadow(
                      color: lit.withAlpha(120),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(
                color: glyphColor,
                fontWeight: FontWeight.w900,
                fontSize: _d * (widget.ps2 ? 0.38 : 0.34),
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}