import 'package:flutter/material.dart';

class AnalogStick extends StatefulWidget {
  final Function(double x, double y) onChanged;

  const AnalogStick({super.key, required this.onChanged});

  @override
  State<AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<AnalogStick> {
  Offset _position = Offset.zero;
  double _deadZone = 0.1;

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final rawPosition = details.localPosition - center;
    final maxRadius = constraints.maxWidth / 2 - 30;

    double x = rawPosition.dx / maxRadius;
    double y = rawPosition.dy / maxRadius;

    final magnitude = (x * x + y * y);
    if (magnitude > 1) {
      x /= magnitude;
      y /= magnitude;
    }

    if (magnitude < _deadZone * _deadZone) {
      x = 0;
      y = 0;
    } else {
      final adjusted = (magnitude - _deadZone * _deadZone) / (1 - _deadZone * _deadZone);
      final scale = adjusted / magnitude;
      x *= scale;
      y *= scale;
    }

    setState(() => _position = Offset(x * maxRadius, y * maxRadius));
    widget.onChanged(x, y);
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() => _position = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (d) => _handlePanUpdate(d, constraints),
          onPanEnd: _handlePanEnd,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                transform: Matrix4.translationValues(_position.dx, _position.dy, 0),
              ),
            ),
          ),
        );
      },
    );
  }
}