import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pulsepad/screens/controller_screen.dart';
import 'package:pulsepad/services/connection_manager.dart';
import 'package:pulsepad/services/layout_store.dart';
import 'package:pulsepad/services/protocol.dart' as p;

/// Taps each pad button directly (single finger, no glide) on the real
/// ControllerScreen and asserts the gamepad bit flips while held and clears on
/// release. Regression guard: a plain tap on EVERY button — especially the two
/// top cells — must register, not just glides.
void main() {
  Future<ConnectionManager> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(731, 411);
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
    return cm;
  }

  /// Down on [finder]'s visual centre, assert bit set (lo or hi byte),
  /// release, assert cleared.
  Future<void> pressRelease(
    WidgetTester tester,
    ConnectionManager cm,
    Finder finder, {
    required int bit,
    required bool hi,
  }) async {
    final f = finder.first;
    expect(f, findsOneWidget,
        reason: 'button widget must render to tap it');
    final center = tester.getCenter(f);
    final g = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 50));
    final value = hi ? cm.controller.buttonsHi : cm.controller.buttonsLo;
    expect(value & bit, bit,
        reason: 'hold must set bit 0x${bit.toRadixString(16)} '
            '(${hi ? "hi" : "lo"}) at $center');
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
    final after = hi ? cm.controller.buttonsHi : cm.controller.buttonsLo;
    expect(after & bit, 0, reason: 'release must clear bit');
  }

  group('DPad direct taps', () {
    testWidgets('every direction registers', (tester) async {
      final cm = await pumpScreen(tester);

      await pressRelease(
          tester, cm, find.byIcon(Icons.keyboard_arrow_up),
          bit: p.kBtnDpadUp, hi: true);
      await pressRelease(
          tester, cm, find.byIcon(Icons.keyboard_arrow_down),
          bit: p.kBtnDpadDown, hi: true);
      await pressRelease(
          tester, cm, find.byIcon(Icons.keyboard_arrow_left),
          bit: p.kBtnDpadLeft, hi: true);
      await pressRelease(
          tester, cm, find.byIcon(Icons.keyboard_arrow_right),
          bit: p.kBtnDpadRight, hi: true);
    });
  });

  group('FacePad direct taps', () {
    testWidgets('every glyph registers', (tester) async {
      final cm = await pumpScreen(tester);

      await pressRelease(tester, cm, find.text('▲'),
          bit: p.kBtnY, hi: false);
      await pressRelease(tester, cm, find.text('●'),
          bit: p.kBtnB, hi: false);
      await pressRelease(tester, cm, find.text('✕'),
          bit: p.kBtnA, hi: false);
      await pressRelease(tester, cm, find.text('■'),
          bit: p.kBtnX, hi: false);
    });
  });
}