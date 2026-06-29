import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation/app_routes.dart';
import 'screens/fleet/auth_gate.dart';
import 'screens/fleet/app_guide_screen.dart';
import 'screens/fleet/fleet_home_shell.dart';
import 'screens/fleet/login_screen.dart';
import 'screens/fleet/personal_data_screen.dart';
import 'services/api_config.dart';
import 'services/native_notification_service.dart';
import 'theme/app_brand.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'wheello bootstrap',
        context: ErrorDescription('while setting device orientation'),
      ),
    );
  }

  try {
    await NativeNotificationService.instance.initialize();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'wheello bootstrap',
        context: ErrorDescription('while initializing notifications'),
      ),
    );
  }

  var startupUnavailable = false;
  try {
    await ApiConfig.loadEnvironment();
    ApiConfig.baseUri;
  } catch (error, stackTrace) {
    startupUnavailable = true;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'wheello bootstrap',
        context: ErrorDescription('while loading API configuration'),
      ),
    );
  }

  runApp(WheelloApp(startupUnavailable: startupUnavailable));
}

class WheelloApp extends StatelessWidget {
  const WheelloApp({
    super.key,
    this.forceLogin = false,
    this.startupUnavailable = false,
  });

  final bool forceLogin;
  final bool startupUnavailable;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: startupUnavailable
          ? const _StartupUnavailableScreen()
          : forceLogin
          ? const LoginScreen()
          : const AuthGate(),
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.home: (context) => const FleetHomeShell(),
        AppRoutes.appGuide: (context) => const AppGuideScreen(),
        AppRoutes.personalData: (context) => const PersonalDataScreen(),
      },
    );
  }
}

class _StartupUnavailableScreen extends StatelessWidget {
  const _StartupUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nous sommes en maintenance, veuillez nous excuser',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
