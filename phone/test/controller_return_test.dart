import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pulsepad/screens/connection_screen.dart';
import 'package:pulsepad/screens/controller_screen.dart';
import 'package:pulsepad/models/packet.dart';
import 'package:pulsepad/services/connection_manager.dart';
import 'package:pulsepad/services/layout_store.dart';

/// Verifies that a blank-screen can never happen after disconnect.
/// Before the fix, `_exit()` called `Navigator.pop` on the only route,
/// emptying the navigator stack.  Now the listener pushes
/// ConnectionScreen back via `pushReplacement`.
void main() {
  Future<void> pumpController(
      WidgetTester tester, ConnectionManager cm) async {
    tester.view.physicalSize = const Size(731, 411);
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
    // Avoid pumpAndSettle — the latency-loop timer and the reconnect timer
    // keep dirtying the tree.  A couple of explicit pumps are enough.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  testWidgets('ControllerScreen renders normally', (tester) async {
    final cm = ConnectionManager();
    await pumpController(tester, cm);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    cm.dispose();
  });

  testWidgets('manual Disconnect while "connected" lands on ConnectionScreen',
      (tester) async {
    final cm = ConnectionManager();

    // Simulate a running connection.  forceState sets the internal state
    // to `connected` and fires notifyListeners.  ControllerScreen's
    // initState will read state == connected as its `_lastStatus`.
    cm.forceState(ConnectionStatus.connected);
    await pumpController(tester, cm);

    // Verify the widget sees the connected state.
    expect(cm.state, ConnectionStatus.connected);

    // Open the in-game menu and tap Disconnect.
    await tester.tap(find.byIcon(Icons.menu).hitTestable().first);
    await tester.pump(const Duration(milliseconds: 100));
    final disconnect = find.text('Disconnect');
    await tester.ensureVisible(disconnect);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(disconnect, warnIfMissed: false);
    // Material route transition = 300 ms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConnectionScreen), findsOneWidget,
        reason: 'must navigate to the main page, not blank');
    expect(find.text('Not connected'), findsOneWidget);
    expect(cm.state, ConnectionStatus.disconnected);

    cm.dispose();
  });

  testWidgets('unexpected loss auto-returns to ConnectionScreen', (tester) async {
    final cm = ConnectionManager();
    cm.forceState(ConnectionStatus.connected);
    await pumpController(tester, cm);

    // Simulate a cable unplug: force to disconnected (same as
    // _onTransportLost firing).  The listener detects the transition.
    cm.forceState(ConnectionStatus.disconnected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConnectionScreen), findsOneWidget,
        reason: 'lost link must send the player back to the main page');
    expect(find.text('Not connected'), findsOneWidget);

    cm.dispose();
  });
}
