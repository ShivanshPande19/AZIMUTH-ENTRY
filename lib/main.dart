import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'theme.dart';
import 'screens/auth_gate.dart';
import 'screens/misconfigured_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Supabase renamed the "anon" key to "publishable" key; same value.
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const GateEntryApp());
}

class GateEntryApp extends StatelessWidget {
  const GateEntryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gate Entry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: AppConfig.isConfigured
          ? const AuthGate()
          : const MisconfiguredScreen(),
    );
  }
}
