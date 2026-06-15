import 'package:flutter/material.dart';

import '../../services/auth_session_service.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_top_bar.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onImmediateDeparture,
    required this.onPlanReservation,
  });

  final VoidCallback onImmediateDeparture;
  final VoidCallback onPlanReservation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authSessionService = const AuthSessionService();
  AccountSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandTopBar(
        onNotificationsPressed: () => _openNotifications(context),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _WelcomeHeader(session: _session),
                        const SizedBox(height: 48),
                        _HomeActionCard(
                          title: 'Départ immédiat',
                          subtitle: 'Récupérer un véhicule maintenant',
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          subtitleColor: AppColors.primaryFixed,
                          borderColor: AppColors.primaryContainer,
                          shadowColor: AppColors.primaryShadow,
                          onTap: widget.onImmediateDeparture,
                          icon: Image.asset(
                            AppAssets.wheelloMascot,
                            height: 82,
                            fit: BoxFit.contain,
                            semanticLabel: 'Wheello',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _HomeActionCard(
                          title: 'Faire une réservation',
                          subtitle: 'Planifier un déplacement futur',
                          backgroundColor: AppColors.surfaceLowest,
                          foregroundColor: AppColors.onSurface,
                          subtitleColor: AppColors.onSurfaceVariant,
                          borderColor: AppColors.outlineVariant,
                          shadowColor: AppColors.elevationShadow,
                          onTap: widget.onPlanReservation,
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.primary,
                            size: 58,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadSession() async {
    final session = await _authSessionService.readSession();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = session;
    });
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.session});

  final AccountSession? session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _greeting,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 30,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Que souhaitez-vous faire aujourd’hui ?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String get _greeting {
    final firstName = session?.firstName.trim() ?? '';

    if (firstName.isEmpty) {
      return 'Bonjour';
    }

    return 'Bonjour, $firstName';
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.shadowColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color shadowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 86, child: Center(child: icon)),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
