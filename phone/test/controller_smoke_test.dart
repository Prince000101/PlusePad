import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pulsepad/screens/controller_screen.dart';
import 'package:pulsepad/services/connection_manager.dart';
import 'package:pulsepad/services/layout_store.dart';

/// Renders the controller at landscape sizes and switches through every
/// preset from the in-game menu, asserting no overflow/exception is thrown.
void main() {
  Future<void> pumpController(
      WidgetTester tester, double w, double h, ConnectionManager cm) async {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cm),
          ChangeNotifierProvider.value(value: LayoutStore()),
        ],
        child: const MaterialApp(home: ControllerScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    final menu = find.byIcon(Icons.menu);
    if (menu.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(menu.hitTestable().first);
      await tester.pumpAndSettle();
    }
  }

  Future<void> closeMenu(WidgetTester tester) async {
    // When the menu is open it covers the chrome, so close via the backdrop.
    if (find.byIcon(Icons.menu).hitTestable().evaluate().isEmpty) {
      await tester.tapAt(const Offset(6, 6));
      await tester.pumpAndSettle();
    }
  }

  Future<void> switchTo(WidgetTester tester, String label) async {
    await openMenu(tester);
    final row = find.text(label);
    await tester.ensureVisible(row);
    await tester.tap(row.hitTestable(), warnIfMissed: false);
    await tester.pumpAndSettle();
    await closeMenu(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow opening $label');
  }

  for (final (w, h) in [(640.0, 360.0), (731.0, 411.0), (1080.0, 608.0)]) {
    testWidgets('all layouts render at ${w.toInt()}x${h.toInt()}', (
        tester) async {
      final cm = ConnectionManager();
      await pumpController(tester, w, h, cm);

      expect(tester.takeException(), isNull, reason: 'initial render');
      // Shoulder strip across the top (tester pill order: L2 L1 · R1 R2).
      expect(find.text('L1'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('R2'), findsOneWidget);

      // Default controller renders PS2 face glyphs (▲ ● ✕ ■).
      expect(find.text('▲'), findsOneWidget);
      expect(find.text('●'), findsOneWidget);
      expect(find.text('✕'), findsOneWidget);
      expect(find.text('■'), findsOneWidget);

      expect(cm.buttonFeedback, isTrue, reason: 'feedback default ON');

      for (final label in ['Controller', 'Mouse', 'Keyboard']) {
        await switchTo(tester, label);
      }

      // Scrollable menu itself must be scrollable (sheet) and closeable.
      await openMenu(tester);
      await tester.drag(find.byType(SingleChildScrollView).last,
          const Offset(0, -200));
      await tester.pumpAndSettle();
      await closeMenu(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Drain the pending auto-connect/discovery timeout (5s) so no timer is
      // left pending when the test harness disposes the widget tree.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      cm.dispose();
    });
  }
}