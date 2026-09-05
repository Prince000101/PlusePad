import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnalogStick extends StatefulWidget {
  final Function(double x, double y) onChanged;
  final double size;
  final double deadZone;

  const AnalogStick({
    super.key,
    required this.onChanged,
    this.size = 160,
    this.deadZone = 0.12,
  });

  @override
  State<AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<AnalogStick> {
  Offset _position = Offset.zero;
  final double _stickRadius = 26;

  void _handlePanUpdate(DragUpdateDetails details) {
    final maxRadius = widget.size / 2 - _stickRadius - 8;

    final rawPosition = details.localPosition - Offset(widget.size / 2, widget.size / 2);
    final magnitude = rawPosition.distance;
    final normalizedMagnitude = (magnitude / maxRadius).clamp(0.0, 1.0);

    var x = normalizedMagnitude == 0 ? 0.0 : rawPosition.dx / rawPosition.distance;
    var y = normalizedMagnitude == 0 ? 0.0 : rawPosition.dy / rawPosition.distance;
    x = (x * normalizedMagnitude).clamp(-1.0, 1.0);
    y = (y * normalizedMagnitude).clamp(-1.0, 1.0);

    // Radial dead zone with smooth re-scale above it.
    if (normalizedMagnitude < widget.deadZone) {
      x = 0;
      y = 0;
    } else {
      final adjusted = (normalizedMagnitude - widget.deadZone) / (1 - widget.deadZone);
      final scale = adjusted / normalizedMagnitude;
      x *= scale;
      y *= scale;
    }

    final clampedX = x.clamp(-1.0, 1.0);
    final clampedY = y.clamp(-1.0, 1.0);

    setState(() => _position = Offset(clampedX, clampedY) * maxRadius);
    widget.onChanged(clampedX, clampedY);
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() => _position = Offset.zero);
    widget.onChanged(0, 0);
  }

  bool get _active => _position != Offset.zero;
  double get _size => widget.size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: GestureDetector(
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface,
            border: Border.all(
              color: _active ? AppTheme.accent : AppTheme.hairline,
              width: _active ? 1.6 : 1.2,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 30),
              width: _stickRadius * 2,
              height: _stickRadius * 2,
              transform: Matrix4.translationValues(_position.dx, _position.dy, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _active ? AppTheme.accentAt(0.22) : AppTheme.surfaceBright,
                border: Border.all(
                  color: _active ? AppTheme.accent : AppTheme.hairline,
                  width: _active ? 1.4 : 1.0,
                ),
              ),
              child: Icon(
                Icons.gps_fixed,
                size: _stickRadius * 0.62,
                color: _active ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}