import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_usage_help_dialog.dart';
import '../../widgets/brand_top_bar.dart';
import 'notifications_screen.dart';

class PersonalDataScreen extends StatelessWidget {
  const PersonalDataScreen({super.key, this.onOpenReservationFromNotification});

  final ValueChanged<String>? onOpenReservationFromNotification;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandTopBar(
        showBackButton: true,
        onNotificationsPressed: () => _openNotifications(context),
        onHelpPressed: () =>
            showAppUsageHelp(context, AppUsageHelpTopic.personalData),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: const [
            Text(
              'Données personnelles',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            _PrivacySection(
              title: 'Responsable',
              body:
                  'Wheello est utilisé dans un cadre interne par l’entreprise pour gérer les véhicules professionnels. Le contact interne est le service RH, le référent RGPD ou le responsable désigné par l’entreprise.',
            ),
            _PrivacySection(
              title: 'Pourquoi',
              body:
                  'Les données servent à gérer les réservations, départs, retours, constats, signalements, kilomètres, notifications et accès à l’application.',
            ),
            _PrivacySection(
              title: 'Données utilisées',
              body:
                  'Nom, prénom, adresse e-mail professionnelle, sites, pôle, réservations, véhicules, dates, kilomètres, constats, signalements, photos ou vidéos strictement liées au véhicule, jetons de session et logs de sécurité.',
            ),
            _PrivacySection(
              title: 'Durées',
              body:
                  'Les données métier nécessaires à la traçabilité flotte peuvent être conservées jusqu’à 3 ans avant anonymisation. Les notifications, médias, logs et PDF bilans ont des durées plus courtes selon la politique interne.',
            ),
            _PrivacySection(
              title: 'Accès',
              body:
                  'Les données sont accessibles aux utilisateurs habilités, aux administrateurs Wheello et aux prestataires nécessaires au fonctionnement technique.',
            ),
            _PrivacySection(
              title: 'Vos droits',
              body:
                  'Vous pouvez demander l’accès, la rectification, la limitation ou l’effacement lorsque c’est possible. Contactez le service RH, le référent RGPD ou le responsable interne désigné.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    final reservationId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        settings: const RouteSettings(name: AppRoutes.notifications),
        builder: (_) => const NotificationsScreen(),
      ),
    );

    if (!context.mounted ||
        reservationId == null ||
        reservationId.trim().isEmpty) {
      return;
    }

    onOpenReservationFromNotification?.call(reservationId);
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
