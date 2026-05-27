import 'package:flutter/material.dart';

import 'navigation/app_routes.dart';
import 'screens/fleet/fleet_home_shell.dart';
import 'screens/fleet/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FleetManagerApp());
}

class FleetManagerApp extends StatelessWidget {
  const FleetManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlotteManager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.home: (context) => const FleetHomeShell(),
      },
    );
  }
}
