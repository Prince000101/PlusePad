import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pulsepad/screens/connection_screen.dart';
import 'package:pulsepad/services/connection_manager.dart';

void main() {
  testWidgets('PulsePad connection screen renders', (tester) async {
    final manager = ConnectionManager();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: manager,
        child: const MaterialApp(home: ConnectionScreen()),
      ),
    );

    // Logo + title present.
    expect(find.text('PulsePad'), findsOneWidget);
    // Connection mode cards present.
    expect(find.text('CONNECTION MODE'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsNWidgets(2));
    // Connect button present.
    expect(find.text('CONNECT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // teardown
    manager.dispose();
  });
}
