import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pulsepad/screens/controller_screen.dart';
import 'package:pulsepad/services/connection_manager.dart';
import 'package:pulsepad/services/layout_store.dart';

/// Renders the default gamepad controller and saves a PNG snapshot so the
/// real layout can be inspected without a device.
///
/// Run with:  flutter test test/controller_snapshot_test.dart --update-goldens
/// PNGs land in test/goldens/.
void main() {
  Future<void> shot(WidgetTester tester, String name, double w, double h) async {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cm = ConnectionManager();
    addTearDown(cm.dispose);

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
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ControllerScreen),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('gamepad layout 1080x608', (t) => shot(t, 'gamepad_1080', 1080, 608));
  testWidgets('gamepad layout 731x411', (t) => shot(t, 'gamepad_731', 731, 411));
  testWidgets('gamepad layout 640x360', (t) => shot(t, 'gamepad_640', 640, 360));
}