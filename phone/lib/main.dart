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
      systemNavigationBarColor: AppTheme.bg,
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
          scaffoldBackgroundColor: AppTheme.bg,
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            secondary: AppTheme.accent,
            surface: AppTheme.surface,
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
