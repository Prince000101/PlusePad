import 'package:flutter/material.dart';

/// Dark OLED theme shared by every screen.
///
/// Black canvas, flat grey surfaces separated by hairlines, high-contrast
/// type, and one accent color used for pressed/active/connected states.
class AppTheme {
  AppTheme._();

  // ---- Canvas ----
  static const Color bg = Color(0xFF000000);

  // ---- Surfaces ----
  static const Color surface = Color(0xFF111113);
  static const Color surfaceAlt = Color(0xFF1A1A20);
  static const Color surfaceBright = Color(0xFF24242C);

  // ---- Lines ----
  static const Color hairline = Color(0xFF26262E);
  static const Color hairlineSoft = Color(0xFF19191F);

  // ---- Type ----
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9AA5);
  static const Color textMuted = Color(0xFF5A5A66);

  // ---- The one accent ----
  static const Color accent = Color(0xFF6EA8FE);
  static const Color accentDeep = Color(0xFF2B5BD7);

  // ---- Functional status (small doses, never decorative) ----
  static const Color green = Color(0xFF2ECC71);
  static const Color amber = Color(0xFFF5A623);
  static const Color red = Color(0xFFE74C3C);

  // ---- Geometry / rhythm ----
  static const double touchMin = 48.0;
  static const double radius = 16.0;
  static const double radiusSmall = 10.0;
  static const double spacing = 12.0;

  static Color accentAt(double alpha) => Color.fromRGBO(112, 165, 255, alpha);
  static Color whiteAt(double alpha) => Color.fromRGBO(255, 255, 255, alpha);

  // ---- Composite decorations ----

  /// Flat solid card with a hairline border.
  static BoxDecoration card({
    double radius = AppTheme.radius,
    Color? color,
    Color? border,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? hairline),
    );
  }

  /// Accent-bordered card for active/selected/success states.
  static BoxDecoration cardActive({
    double radius = AppTheme.radius,
    double alpha = 0.14,
  }) {
    return BoxDecoration(
      color: accentAt(alpha),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent, width: 1.2),
    );
  }

  /// Darker control pad, so controls read against surfaces.
  static BoxDecoration pad({
    double radius = AppTheme.radiusSmall,
    Color? color,
    Color? border,
  }) {
    return BoxDecoration(
      color: color ?? surfaceAlt,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? hairline),
    );
  }

  /// Pressed control — brighter fill.
  static BoxDecoration padPressed({
    double radius = AppTheme.radiusSmall,
  }) {
    return BoxDecoration(
      color: accentAt(0.34),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent, width: 2),
    );
  }

  /// Active (toggle-on) control.
  static BoxDecoration padActive({
    double radius = AppTheme.radiusSmall,
  }) {
    return BoxDecoration(
      color: accentAt(0.10),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent, width: 1.2),
    );
  }

  // ---- Type helpers ----
  static const TextStyle label = TextStyle(
    color: textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );

  static const TextStyle caption = TextStyle(
    color: textMuted,
    fontSize: 12,
  );

  static const TextStyle body = TextStyle(
    color: textPrimary,
    fontSize: 15,
  );

  static const TextStyle bodySecondary = TextStyle(
    color: textSecondary,
    fontSize: 14,
  );

  static const TextStyle display = TextStyle(
    color: textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );
}

/// Pure-black stage for every screen; children draw their own surfaces.
class Background extends StatelessWidget {
  const Background({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(color: AppTheme.bg, child: child);
  }
}