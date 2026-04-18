import 'package:flutter/material.dart';
import 'dart:math' as math;

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
  double _baseRadius = 30;
  double _stickRadius = 28;
  double _deadZone = 0.12;

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxRadius = widget.size / 2 - _stickRadius - 10;
          return GestureDetector(
            onPanUpdate: (d) => _handlePanUpdate(d, constraints),
            onPanEnd: _handlePanEnd,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 30),
                  width: _stickRadius * 2,
                  height: _stickRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF818CF8),
                        const Color(0xFF6366F1),
                      ],
                      center: const Alignment(-0.3, -0.3),
                    ),
                    border: Border.all(
                      color: const Color(0xFF818CF8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.5),
                        blurRadius: _position == Offset.zero ? 8 : 20,
                        spreadRadius: _position == Offset.zero ? 1 : 3,
                      ),
                    ],
                  ),
                  transform: Matrix4.translationValues(_position.dx, _position.dy, 0),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}