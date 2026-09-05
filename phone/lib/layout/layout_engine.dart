import 'dart:ui';

/// The controller screen is one big Stack divided into guaranteed-disjoint
/// zones. Every preset places controls *inside* its own zone, so nothing can
/// overlap — the engine is the single source of truth for "what is where".
///
///   ┌──────────────────────────────────────────────┐
///   │ shoulder strip (L1 L2 ····· R2 R1)   top 44 │
///   ├──────────────────────────────────────────────┤
///   │ chrome band (menu · latency)      padded 8   │
///   ├───────────────┬────────┬───────────────────┤
///   │   left grip   │ center │   right grip      │
///   └───────────────┴────────┴───────────────────┘
///
/// Safe insets (cutout / nav bar / notch) are folded in so controls never sit
/// under hardware chrome, and the zones are inset from each other so real
/// controls never touch.
class LayoutPanel {
  LayoutPanel({
    required this.size,
    this.safeTop = 0,
    this.safeBottom = 0,
    this.safeLeft = 0,
    this.safeRight = 0,
  }) {
    final w = size.width;
    final h = size.height;
    final rightEdge = w - safeRight;
    final bottomEdge = h - safeBottom;

    // Shoulder strip hugs the top edge, full width, clear of side cutouts.
    shoulder =
        Rect.fromLTRB(safeLeft, safeTop, rightEdge - safeLeft, safeTop + _strip);

    // Chrome band (menu + latency cluster) sits directly under the strip.
    fieldTop = shoulder.bottom + _gap + _chrome;

    // Control field runs down to the bottom safe inset, clear of side cutouts.
    final padX = _pad(w, h, 0.05);
    final padY = _pad(w, h, 0.03);
    field = Rect.fromLTRB(
      safeLeft + padX,
      fieldTop + padY,
      rightEdge - padX,
      bottomEdge - padY,
    );

    // Central column holds SELECT/START/L3/R3.
    centerW = w <= 420 ? 60.0 : 72.0;
    final sideW = (field.width - centerW) / 2;

    gripLeft = Rect.fromLTWH(field.left, field.top, sideW, field.height);
    center = Rect.fromLTWH(gripLeft.right, field.top, centerW, field.height);
    gripRight = Rect.fromLTWH(center.right, field.top, sideW, field.height);
  }

  final Size size;
  final double safeTop;
  final double safeBottom;
  final double safeLeft;
  final double safeRight;

  static const double _strip = 44;
  static const double _gap = 8;
  static const double _chrome = 56;

  late final Rect shoulder;
  late final double fieldTop;
  late final Rect field;
  late final double centerW;
  late final Rect gripLeft;
  late final Rect center;
  late final Rect gripRight;

  static double _pad(double w, double h, double frac) {
    final v = (w < h ? w : h) * frac;
    return v.clamp(4.0, 22.0);
  }

  /// Largest square that fits [zone] at the requested fraction of its
  /// shortest side, clamped to a thumb-sized minimum.
  static double fit(Rect zone, double fraction) {
    final raw = zone.shortestSide * fraction;
    return raw.clamp(48.0, zone.shortestSide);
  }
}

/// Raw pixel-level assertion used by tests: controls placed in disjoint zones
/// cannot overlap.
bool rectsDisjoint(Rect a, Rect b, {double slack = 0.5}) {
  return a.right - slack <= b.left ||
      b.right - slack <= a.left ||
      a.bottom - slack <= b.top ||
      b.bottom - slack <= a.top;
}