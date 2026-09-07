import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Single OLED-minimal touch control. One visual language for face buttons,
/// bumpers, keys, modifier pills and menu actions.
///
/// Semantics:
///  * press-and-hold buttons use [onDown]/[onUp] (gamepad keys, bumpers)
///  * toggle buttons use [onTap] + [active] (mouse buttons, select/start)
class GamepadButton extends StatefulWidget {
  const GamepadButton({
    super.key,
    required this.label,
    this.icon,
    this.width = 56,
    this.height = 56,
    this.round = false,
    this.active = false,
    this.fontSize = 12,
    this.onDown,
    this.onUp,
    this.onTap,
    this.highlight = false,
  });

  final String label;
  final IconData? icon;
  final double width;
  final double height;
  final bool round;
  final bool active;
  final double fontSize;
  final VoidCallback? onDown;
  final VoidCallback? onUp;
  final VoidCallback? onTap;

  /// Renders with an accent ring regardless of press state (primary CTA etc).
  final bool highlight;

  @override
  State<GamepadButton> createState() => _GamepadButtonState();
}

class _GamepadButtonState extends State<GamepadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
  bool _pressed = false;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _down() {
    _pressed = true;
    _scale.forward();
    widget.onDown?.call();
  }

  void _up() {
    if (!_pressed) return;
    _pressed = false;
    _scale.reverse();
    widget.onUp?.call();
  }

  @override
  Widget build(BuildContext context) {
    final activated = _pressed || widget.active;
    final BoxDecoration deco = activated
        ? AppTheme.padPressed(radius: widget.round ? 999 : AppTheme.radiusSmall)
        : widget.highlight
            ? AppTheme.padActive(radius:
                widget.round ? 999 : AppTheme.radiusSmall)
            : AppTheme.pad(radius: widget.round ? 999 : AppTheme.radiusSmall);

    final Color fg = activated
        ? Colors.white
        : widget.highlight
            ? AppTheme.accent
            : AppTheme.textPrimary;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) {
        final s = 1.0 - 0.10 * _scale.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(),
          onTapCancel: _up,
          onTap: widget.onTap,
          child: Transform.scale(
            scale: s,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: deco,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null)
                      Icon(widget.icon,
                          size: widget.fontSize + 6,
                          color: activated
                              ? Colors.white
                              : AppTheme.textSecondary),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}