import 'package:flutter/material.dart';

import 'navigation/app_routes.dart';
import 'screens/fleet/auth_gate.dart';
import 'screens/fleet/fleet_home_shell.dart';
import 'screens/fleet/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FleetManagerApp());
}

class FleetManagerApp extends StatelessWidget {
  const FleetManagerApp({super.key, this.forceLogin = false});

  final bool forceLogin;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlotteManager',
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
