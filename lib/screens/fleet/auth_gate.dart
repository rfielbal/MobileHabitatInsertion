import 'package:flutter/material.dart';

import '../../services/auth_session_service.dart';
import '../../theme/app_colors.dart';
import 'fleet_home_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authSessionService = const AuthSessionService();
  late final Future<bool> _hasValidSession = _loadSession();

  Future<bool> _loadSession() async {
    final session = await _authSessionService.readSession();
    return session != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasValidSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.surfaceLowest,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data ?? false) {
          return const FleetHomeShell();
        }

        return const LoginScreen();
      },
    );
  }
}
