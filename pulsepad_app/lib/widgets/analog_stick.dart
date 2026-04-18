import 'package:flutter/material.dart';

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
  double _deadZone = 0.1;

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final maxRadius = widget.size / 2 - 35;
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final rawPosition = details.localPosition - center;

    double x = rawPosition.dx / maxRadius.clamp(1, double.infinity);
    double y = rawPosition.dy / maxRadius.clamp(1, double.infinity);

    final magnitude = (x * x + y * y);
    
    if (magnitude > 1) {
      x /= magnitude;
      y /= magnitude;
    }

    if (magnitude < _deadZone * _deadZone) {
      x = 0;
      y = 0;
    } else {
      final adjusted = magnitude > _deadZone * _deadZone 
          ? (magnitude - _deadZone * _deadZone) / (1 - _deadZone * _deadZone)
          : 0.0;
      final scale = magnitude > 0 ? adjusted.clamp(0, 1) / magnitude.clamp(0.001, double.infinity) : 0;
      x *= scale;
      y *= scale;
    }

    final clampedX = (x * maxRadius).clamp(-maxRadius, maxRadius);
    final clampedY = (y * maxRadius).clamp(-maxRadius, maxRadius);
    
    setState(() => _position = Offset(clampedX, clampedY));
    widget.onChanged(x.clamp(-1, 1), y.clamp(-1, 1));
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
          final maxRadius = widget.size / 2 - 35;
          return GestureDetector(
            onPanUpdate: (d) => _handlePanUpdate(d, constraints),
            onPanEnd: _handlePanEnd,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155), width: 2),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.5),
                        blurRadius: _position == Offset.zero ? 10 : 25,
                        spreadRadius: _position == Offset.zero ? 2 : 5,
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