import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/connection_manager.dart';
import 'screens/connection_screen.dart';

void main() {
  runApp(const PulsePadApp());
}

class PulsePadApp extends StatelessWidget {
  const PulsePadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConnectionManager(),
      child: MaterialApp(
        title: 'PulsePad',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF6366F1),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
        ),
        home: const ConnectionScreen(),
      ),
    );
  }
}