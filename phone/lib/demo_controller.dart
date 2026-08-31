import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/connection_manager.dart';
import 'screens/controller_screen.dart';

/// Chrome-only preview entrypoint.
///
/// Renders the controller UI directly without any network transport so you can
/// iterate on the look in the browser:
///
///   flutter run -d chrome -t lib/demo_controller.dart
///
/// It deliberately does NOT touch [ConnectionManager]'s socket logic and is not
/// used by the normal `main.dart` / APK build.
class _DemoConnectionManager extends ConnectionManager {
  @override
  void enableAutoReconnect() {
    // No-op: never try to actually (re)connect in the UI preview.
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => _DemoConnectionManager(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PulsePad UI Preview',
        home: Scaffold(body: SafeArea(child: ControllerScreen())),
      ),
    ),
  );
}
