import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_top_bar.dart';
import 'notifications_screen.dart';

class AppGuideScreen extends StatelessWidget {
  const AppGuideScreen({super.key, this.onOpenReservationFromNotification});

  final ValueChanged<String>? onOpenReservationFromNotification;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandTopBar(
        showBackButton: true,
        onNotificationsPressed: () => _openNotifications(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: const [
            Text(
              'Guide d’utilisation',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les repères essentiels pour utiliser Wheello sans hésiter.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            _GuideSection(
              icon: Icons.home_outlined,
              title: 'Accueil',
              body:
                  'Choisissez entre un départ immédiat, une réservation classique ou la consultation de vos alertes. Si une action n’apparaît pas, elle n’est pas disponible dans l’état actuel de vos réservations.',
            ),
            _GuideSection(
              icon: Icons.directions_car_outlined,
              title: 'Véhicules',
              body:
                  'Recherchez un véhicule, filtrez par site ou statut, puis ouvrez sa fiche pour voir ses informations et ses disponibilités.',
            ),
            _GuideSection(
              icon: Icons.calendar_month_outlined,
              title: 'Réserver',
              body:
                  'Choisissez un véhicule, une date et un horaire. L’application vérifie les conflits et applique le tampon d’une heure entre deux réservations.',
            ),
            _GuideSection(
              icon: Icons.play_circle_outline,
              title: 'Départ immédiat',
              body:
                  'Utilisez ce parcours uniquement lorsque vous prenez un véhicule maintenant. Il crée la réservation puis démarre directement le trajet.',
            ),
            _GuideSection(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Départ et retour',
              body:
                  'Au moment du départ, confirmez le kilométrage. Au retour, indiquez le kilométrage final et validez pour libérer le véhicule.',
            ),
            _GuideSection(
              icon: Icons.report_problem_outlined,
              title: 'Signalements',
              body:
                  'Signalez uniquement une anomalie liée au véhicule. Les photos ou vidéos doivent rester utiles, courtes et sans données personnelles inutiles.',
            ),
            _GuideSection(
              icon: Icons.notifications_none,
              title: 'Notifications',
              body:
                  'Les notifications rappellent les départs, retours ou événements importants. Elles fonctionnent localement quand elles sont autorisées sur le téléphone.',
            ),
            _GuideSection(
              icon: Icons.privacy_tip_outlined,
              title: 'Données personnelles',
              body:
                  'La page dédiée explique quelles données sont utilisées, pourquoi, combien de temps elles sont conservées et qui contacter pour exercer vos droits.',
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

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
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
          ],
        ),
      ),
    );
  }
}
