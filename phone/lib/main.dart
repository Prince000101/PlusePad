import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/connection_manager.dart';
import 'services/layout_store.dart';
import 'screens/connection_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LayoutStore();
  await store.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(PulsePadApp(layoutStore: store));
}

class PulsePadApp extends StatelessWidget {
  const PulsePadApp({super.key, this.layoutStore});
  final LayoutStore? layoutStore;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProvider<LayoutStore>(
            create: (_) => layoutStore ?? LayoutStore()..load()),
      ],
      child: MaterialApp(
        title: 'PulsePad',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentA,
            secondary: AppTheme.accentB,
            surface: Color(0xFF1E293B),
            error: AppTheme.red,
          ),
          fontFamily: 'Roboto',
          splashFactory: InkRipple.splashFactory,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
        ),
        home: const ConnectionScreen(),
      ),
    );
  }
}
