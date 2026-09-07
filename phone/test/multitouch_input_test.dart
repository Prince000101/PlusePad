import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulsepad/widgets/dpad.dart';
import 'package:pulsepad/widgets/face_pad.dart';

/// Two fingers on a cross pad must both register (diagonals / combos), and a
/// single finger gliding through the centre gap must release cleanly instead
/// of leaving a stale arm pressed ("drag in middle = both inputs").
void main() {
  const size = 180.0;

  /// Current held set derived from the onChanged log: the last entry per arm.
  Set<String> heldFromLog(List<String> log) {
    final held = <String, bool>{};
    for (final e in log) {
      final bits = e.split(':');
      held[bits[0]] = bits[1] == 'true';
    }
    return held.entries.where((e) => e.value).map((e) => e.key).toSet();
  }

  Offset armAt(WidgetTester tester, Finder finder, String kind, String dir) {
    final c = tester.getCenter(finder);
    final d = dir;
    switch (kind) {
      case 'up':
        return Offset(c.dx, c.dy - size / 3);
      case 'down':
        return Offset(c.dx, c.dy + size / 3);
      case 'left':
        return Offset(c.dx - size / 3, c.dy);
      case 'right':
        return Offset(c.dx + size / 3, c.dy);
      case 'center':
        return c;
      default:
        throw ArgumentError(d);
    }
  }

  group('DPad multi-touch', () {
    testWidgets('two pointers hold UP + RIGHT simultaneously', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(child: DPad(size: size, onChanged: (d, p) => log.add('$d:$p'))),
      ));

      final finder = find.byType(DPad);
      final g1 = await tester.startGesture(armAt(tester, finder, 'up', ''), pointer: 1);
      await tester.pump();
      final g2 =
          await tester.startGesture(armAt(tester, finder, 'right', ''), pointer: 2);
      await tester.pump();

      expect(heldFromLog(log), containsAll(['DPAD_UP', 'DPAD_RIGHT']));

      await g2.up();
      await tester.pump();
      expect(heldFromLog(log), {'DPAD_UP'});

      await g1.up();
      await tester.pump();
      expect(heldFromLog(log), isEmpty);
    });

    testWidgets('dragging through the centre gap releases the held arm',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(child: DPad(size: size, onChanged: (d, p) => log.add('$d:$p'))),
      ));

      final finder = find.byType(DPad);
      final g = await tester.startGesture(armAt(tester, finder, 'up', ''));
      await tester.pump();
      expect(heldFromLog(log), {'DPAD_UP'});

      // Slide into the centre dead-zone: the arm must release.
      await g.moveBy(const Offset(0, size / 3));
      await tester.pump();
      expect(heldFromLog(log), isEmpty);

      await g.up();
      await tester.pump();
      expect(heldFromLog(log), isEmpty);
    });

    testWidgets('gliding from LEFT to RIGHT switches, no overlap',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(child: DPad(size: size, onChanged: (d, p) => log.add('$d:$p'))),
      ));

      final finder = find.byType(DPad);
      final g = await tester.startGesture(armAt(tester, finder, 'left', ''));
      await tester.pump();
      expect(heldFromLog(log), {'DPAD_LEFT'});

      await g.moveBy(const Offset(size * 2 / 3, 0));
      await tester.pump();
      expect(heldFromLog(log), {'DPAD_RIGHT'});

      await g.up();
      await tester.pump();
      expect(heldFromLog(log), isEmpty);
    });
  });

  group('FacePad multi-touch', () {
    testWidgets('two pointers hold ▲ + ■ simultaneously', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(child: FacePad(size: size, onChanged: (b, p) => log.add('$b:$p'))),
      ));

      final finder = find.byType(FacePad);
      final g1 = await tester.startGesture(armAt(tester, finder, 'up', ''), pointer: 1);
      await tester.pump();
      final g2 =
          await tester.startGesture(armAt(tester, finder, 'left', ''), pointer: 2);
      await tester.pump();

      expect(heldFromLog(log), containsAll(['Y', 'X']));

      await g2.up();
      await tester.pump();
      expect(heldFromLog(log), {'Y'});

      await g1.up();
      await tester.pump();
      expect(heldFromLog(log), isEmpty);
    });

    testWidgets('dragging through the centre gap releases the held button',
        (tester) async {
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(child: FacePad(size: size, onChanged: (b, p) => log.add('$b:$p'))),
      ));

      final finder = find.byType(FacePad);
      final g = await tester.startGesture(armAt(tester, finder, 'left', ''));
      await tester.pump();
      expect(heldFromLog(log), {'X'});

      await g.moveBy(const Offset(size / 3, 0));
      await tester.pump();
      expect(heldFromLog(log), isEmpty);

      await g.up();
      await tester.pump();
      expect(heldFromLog(log), isEmpty);
    });
  });
}