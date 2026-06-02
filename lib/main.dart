import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'navigation/app_routes.dart';
import 'screens/fleet/auth_gate.dart';
import 'screens/fleet/fleet_home_shell.dart';
import 'screens/fleet/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env.local');
  runApp(const WheelloApp());
}

class WheelloApp extends StatelessWidget {
  const WheelloApp({super.key, this.forceLogin = false});

  final bool forceLogin;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wheello',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: forceLogin ? const LoginScreen() : const AuthGate(),
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.home: (context) => const FleetHomeShell(),
      },
    );
  }
}
