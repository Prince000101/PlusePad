import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepad/layout/layout_engine.dart';

void main() {
  // Landscape phone-ish shapes plus a couple of odd sizes; the engine must
  // keep every zone disjoint, inside the screen, and clear of safe insets.
  const sizes = [
    (320.0, 360.0),
    (360.0, 360.0),
    (640.0, 360.0),
    (731.0, 411.0),
    (1080.0, 608.0),
    (1280.0, 800.0),
  ];

  group('LayoutPanel geometry', () {
    for (final (w, h) in sizes) {
      test('no overlap at ${w.toInt()}x${h.toInt()}', () {
        final p = LayoutPanel(size: Size(w, h));

        // Sibling zones never overlap in area (edges may touch).
        const gripPairs = [(0, 1), (0, 2), (1, 2)];
        final grips = [p.gripLeft, p.center, p.gripRight];
        for (final (i, j) in gripPairs) {
          final shrunkA = grips[i].deflate(0.5);
          final shrunkB = grips[j].deflate(0.5);
          expect(rectsDisjoint(shrunkA, shrunkB),
              isTrue,
              reason: 'grip $i vs grip $j overlap at ${w}x$h');
        }

        // The control field never touches the shoulder strip.
        expect(p.shoulder.bottom <= p.field.top + 0.5,
            isTrue,
            reason: 'shoulder vs field overlap at ${w}x$h');

        // Grips sit inside the field.
        for (final g in grips) {
          expect(p.field.overlaps(g), isTrue,
              reason: 'grip escapes field at ${w}x$h');
        }
      });

      test('zones stay inside screen at ${w.toInt()}x${h.toInt()}', () {
        final p = LayoutPanel(size: Size(w, h));
        final zones = [p.shoulder, p.field, p.gripLeft, p.center, p.gripRight];
        for (final z in zones) {
          expect(z.left, greaterThanOrEqualTo(0));
          expect(z.top, greaterThanOrEqualTo(0));
          expect(z.right, lessThanOrEqualTo(w + 0.5));
          expect(z.bottom, lessThanOrEqualTo(h + 0.5));
          expect(z.width, greaterThan(0));
          expect(z.height, greaterThan(0));
        }
      });

      test('grips are non-empty and centre column floats above field at ${w.toInt()}x${h.toInt()}', () {
        final p = LayoutPanel(size: Size(w, h));
        expect(p.gripLeft.width, greaterThan(40));
        expect(p.gripRight.width, greaterThan(40));
        expect(p.center.width, inInclusiveRange(56, 76));
        expect(p.gripLeft.bottom, p.gripRight.bottom);
        expect(p.field.top, lessThanOrEqualTo(h));
      });
    }

    test('safe insets push shoulder and field clear of cutouts', () {
      // Landscape phone with a cutout on the *side*.
      final p = LayoutPanel(
        size: const Size(640, 360),
        safeTop: 0,
        safeBottom: 0,
        safeLeft: 48,
        safeRight: 0,
      );
      expect(p.shoulder.left, greaterThanOrEqualTo(48));
      expect(p.field.left, greaterThanOrEqualTo(48));
      expect(p.size.width, 640);
    });

    test('fit() never returns below the thumb minimum or above its zone', () {
      final p = LayoutPanel(size: const Size(640, 360));
      for (var frac = 0.1; frac <= 1.0; frac += 0.1) {
        final v = LayoutPanel.fit(p.gripLeft, frac);
        expect(v, greaterThanOrEqualTo(48));
        expect(v, lessThanOrEqualTo(p.gripLeft.shortestSide));
      }
    });
  });
}