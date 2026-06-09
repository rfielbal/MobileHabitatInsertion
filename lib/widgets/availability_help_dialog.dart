import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AvailabilityHelpDialog extends StatelessWidget {
  const AvailabilityHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Comprendre le calendrier'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvailabilityHelpItem(
              color: AppColors.available,
              title: 'Libre',
              description:
                  'Le véhicule peut être réservé sur cette journée, selon les heures sélectionnées.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.partial,
              title: 'Partiel',
              description:
                  'Une partie de la journée est déjà prise. L’application propose automatiquement la première heure possible ou la dernière heure de retour possible.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.error,
              title: 'Réservé',
              description:
                  'Le véhicule est réservé sur toute la journée et ne peut pas être sélectionné.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.maintenance,
              title: 'Maintenance',
              description:
                  'Le véhicule est indisponible administrativement et ne peut pas être réservé.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.userUnavailable,
              title: 'Indisponible pour moi',
              description:
                  'Vous avez déjà une réservation active sur cette période, même si le véhicule affiché est libre.',
            ),
            SizedBox(height: 8),
            Text(
              'Sélection : appuyez une première fois pour choisir le départ, puis une deuxième fois pour choisir le retour. Les jours passés ne sont pas sélectionnables.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Compris'),
        ),
      ],
    );
  }
}

class _AvailabilityHelpItem extends StatelessWidget {
  const _AvailabilityHelpItem({
    required this.color,
    required this.title,
    required this.description,
  });

  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 12,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
