import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulsepad/models/control_slot.dart';
import 'package:pulsepad/screens/controller_screen.dart';
import 'package:pulsepad/services/connection_manager.dart';
import 'package:pulsepad/services/layout_store.dart';

/// Renders the Custom layout with typed button actions and switches to it via
/// the menu, asserting no exception and that the configured controls appear.
void main() {
  testWidgets('custom layout renders pad/key/mouse buttons', (tester) async {
    tester.view.physicalSize = const Size(731, 411);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final store = LayoutStore();
    await store.load();
    await store.save(CustomLayout(
      id: CustomLayout.newId(),
      name: 'My Custom',
      slots: [
        ControlSlot(
            id: 'k',
            kind: 'button',
            x: 0.25,
            y: 0.30,
            w: 0.18,
            h: 0.16,
            label: 'JUMP',
            action: 'key:W'),
        ControlSlot(
            id: 'm',
            kind: 'button',
            x: 0.75,
            y: 0.30,
            w: 0.18,
            h: 0.16,
            label: 'CLICK',
            action: 'mouse:LMB'),
        ControlSlot(
            id: 'p',
            kind: 'button',
            x: 0.50,
            y: 0.70,
            w: 0.18,
            h: 0.16,
            label: 'PAD',
            action: 'pad:A'),
      ],
    ));

    final cm = ConnectionManager();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cm),
          ChangeNotifierProvider.value(value: store),
        ],
        child: const MaterialApp(home: ControllerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to custom via the menu (layout row is listed when one exists).
    await tester.tap(find.byIcon(Icons.menu).hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('MY LAYOUTS'), findsOneWidget);
    await tester.tap(find.text('My Custom'));
    await tester.pumpAndSettle();

    // Three configured buttons render (custom layout, not the default one).
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.text('CLICK'), findsOneWidget);
    expect(find.text('PAD'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    cm.dispose();
  });
}