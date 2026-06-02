import 'package:flutter/material.dart';

import '../../services/api_exception.dart';
import '../../services/auth_api_service.dart';
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
  final _authApiService = AuthApiService();
  late final Future<bool> _hasValidSession = _loadSession();

  Future<bool> _loadSession() async {
    final session = await _authSessionService.readSession();
    if (session == null) {
      return false;
    }

    if (session.isMockSession) {
      await _authSessionService.clearSession();
      return false;
    }

    try {
      await _authApiService.refreshStoredSession(session);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _authSessionService.clearSession();
        return false;
      }

      return true;
    } catch (_) {
      return true;
    }
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
