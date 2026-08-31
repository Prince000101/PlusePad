import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnalogStick extends StatefulWidget {
  final Function(double x, double y) onChanged;
  final double size;

  const AnalogStick({
    super.key,
    required this.onChanged,
    this.size = 200,
  });

  @override
  State<AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<AnalogStick> {
  Offset _position = Offset.zero;
  final double _stickRadius = 28;
  final double _deadZone = 0.12;

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final maxRadius = widget.size / 2 - _stickRadius - 10;

    final rawPosition = details.localPosition - center;
    final magnitude = rawPosition.distance;
    final normalizedMagnitude = magnitude / maxRadius;

    double x = rawPosition.dx / maxRadius;
    double y = rawPosition.dy / maxRadius;

    if (normalizedMagnitude > 1) {
      final scale = 1 / normalizedMagnitude;
      x *= scale;
      y *= scale;
    }

    final clampedMagnitude = normalizedMagnitude.clamp(0.0, 1.0);

    if (clampedMagnitude < _deadZone) {
      x = 0;
      y = 0;
    } else {
      final adjusted = (clampedMagnitude - _deadZone) / (1 - _deadZone);
      final scale = adjusted / clampedMagnitude.clamp(0.001, double.infinity);
      x *= scale;
      y *= scale;
    }

    final clampedX = x.clamp(-1.0, 1.0);
    final clampedY = y.clamp(-1.0, 1.0);
    final outputX = clampedX * maxRadius;
    final outputY = clampedY * maxRadius;

    setState(() => _position = Offset(outputX, outputY));
    widget.onChanged(clampedX, clampedY);
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() => _position = Offset.zero);
    widget.onChanged(0, 0);
  }

  bool get _active => _position != Offset.zero;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanUpdate: (d) => _handlePanUpdate(d, BoxConstraints.tight(Size(widget.size, widget.size))),
        onPanEnd: _handlePanEnd,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF10162B), Color(0xFF0A0F20)],
              center: Alignment(-0.2, -0.2),
            ),
            border: Border.all(color: AppTheme.hairline, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 14,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: AppTheme.accentA.withOpacity(_active ? 0.35 : 0.10),
                blurRadius: _active ? 22 : 10,
                spreadRadius: _active ? 2 : 0,
              ),
            ],
          ),
          child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 30),
                width: _stickRadius * 2,
                height: _stickRadius * 2,
                transform: Matrix4.translationValues(_position.dx, _position.dy, 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.lerp(AppTheme.accentB, Colors.white, 0.18)!,
                      AppTheme.accentB,
                      AppTheme.accentA,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentA.withOpacity(_active ? 0.7 : 0.45),
                      blurRadius: _active ? 22 : 12,
                      spreadRadius: _active ? 3 : 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // soft inner gloss highlight
                    Positioned(
                      top: 5,
                      child: Container(
                        width: _stickRadius - 4,
                        height: _stickRadius - 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white24, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.gps_fixed,
                      size: _stickRadius * 0.6,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }
}
