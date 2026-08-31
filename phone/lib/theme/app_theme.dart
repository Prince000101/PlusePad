import 'package:flutter/material.dart';

/// Central design tokens for the KDE-Connect-style glassy/dark look.
class AppTheme {
  // Background
  static const Color bgTop = Color(0xFF12182B);
  static const Color bgBottom = Color(0xFF0B1120);

  // Accent gradient
  static const Color accentA = Color(0xFF6366F1);
  static const Color accentB = Color(0xFF818CF8);

  // Surface / frost
  static const Color frost = Color(0x0DFFFFFF); // ~5% white glass
  static const Color frostStrong = Color(0x1AFFFFFF); // ~10% white glass
  static const Color hairline = Color(0x26FFFFFF); // faint glass edge

  static const Color green = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);

  static LinearGradient get bgGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bgTop, bgBottom],
      );

  static LinearGradient get accentGradient =>
      const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accentB, accentA]);

  /// A frosted glass surface with a soft drop shadow.
  static BoxDecoration glass({
    double radius = 16,
    Color? tint,
    double blur = 18,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (tint ?? Colors.white).withOpacity(0.09),
          (tint ?? Colors.white).withOpacity(0.04),
        ],
      ),
      border: Border.all(color: hairline, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: blur,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: accentA.withOpacity(0.06),
          blurRadius: blur,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Ambient glow shadow for active controls.
  static List<BoxShadow> glow(Color color, {double opacity = 0.45, double blur = 18}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blur,
        spreadRadius: 1,
        offset: Offset.zero,
      ),
    ];
  }
}

/// A full-screen background painted with the brand gradient. Drop behind the
/// body of every Scaffold for a seamless look.
class Background extends StatelessWidget {
  const Background({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.bgTop, AppTheme.bgBottom],
        ),
      ),
      child: child,
    );
  }
}
