import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';

enum AppUsageHelpTopic {
  home,
  vehicles,
  bookings,
  immediateDeparture,
  profile,
  personalData,
}

Future<void> showAppUsageHelp(BuildContext context, AppUsageHelpTopic topic) {
  final content = _contentForTopic(topic);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(content.title)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.intro,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              for (final step in content.steps) ...[
                _GuideStep(step: step),
                if (step != content.steps.last) const SizedBox(height: 10),
              ],
              if (content.tip != null) ...[
                const SizedBox(height: 14),
                _GuideTip(text: content.tip!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Compris'),
        ),
      ],
    ),
  );
}

_GuideContent _contentForTopic(AppUsageHelpTopic topic) {
  return switch (topic) {
    AppUsageHelpTopic.home => const _GuideContent(
      title: 'Guide de l’accueil',
      intro:
          'Cette page sert à choisir rapidement le bon parcours selon votre besoin.',
      steps: [
        _GuideStepData(
          icon: Icons.play_circle_outline,
          title: 'Départ immédiat',
          body:
              'À utiliser si vous prenez un véhicule maintenant. L’application crée la réservation et ouvre directement le trajet.',
        ),
        _GuideStepData(
          icon: Icons.calendar_month_outlined,
          title: 'Faire une réservation',
          body:
              'À utiliser pour réserver un véhicule plus tard. Vous choisissez le véhicule, les dates et les horaires.',
        ),
        _GuideStepData(
          icon: Icons.help_outline,
          title: 'Guide d’utilisation',
          body:
              'Ouvrez le guide complet pour retrouver les principaux parcours de l’application.',
        ),
        _GuideStepData(
          icon: Icons.notifications_none,
          title: 'Notifications',
          body:
              'Consultez les alertes si une action est attendue : départ à confirmer, retour à faire ou réservation supprimée.',
        ),
      ],
      tip:
          'Si un bouton n’apparaît pas, c’est que l’action n’est pas encore disponible pour votre réservation.',
    ),
    AppUsageHelpTopic.vehicles => const _GuideContent(
      title: 'Guide des véhicules',
      intro:
          'Cette page permet de consulter le parc accessible et de lancer une réservation classique.',
      steps: [
        _GuideStepData(
          icon: Icons.search,
          title: 'Rechercher',
          body:
              'Utilisez la recherche pour retrouver un véhicule par numéro, modèle ou plaque.',
        ),
        _GuideStepData(
          icon: Icons.tune_outlined,
          title: 'Filtrer',
          body:
              'Affinez la liste par site ou marque pour ne garder que les véhicules pertinents.',
        ),
        _GuideStepData(
          icon: Icons.calendar_month_outlined,
          title: 'Réserver',
          body:
              'Ouvrez la fiche d’un véhicule pour consulter ses disponibilités et choisir votre créneau.',
        ),
      ],
      tip:
          'Les véhicules les plus proches et les moins kilométrés sont proposés en priorité.',
    ),
    AppUsageHelpTopic.bookings => const _GuideContent(
      title: 'Guide des réservations',
      intro:
          'Cette page regroupe vos réservations à venir et votre historique.',
      steps: [
        _GuideStepData(
          icon: Icons.event_available_outlined,
          title: 'Suivre le planning',
          body:
              'Le calendrier montre vos périodes réservées. La liste dessous donne le détail véhicule par véhicule.',
        ),
        _GuideStepData(
          icon: Icons.edit_calendar_outlined,
          title: 'Modifier ou supprimer',
          body:
              'Avant le verrouillage, vous pouvez modifier le créneau ou annuler la réservation depuis sa carte.',
        ),
        _GuideStepData(
          icon: Icons.assignment_turned_in_outlined,
          title: 'Départ et retour',
          body:
              'Quand le moment arrive, le bouton de la carte permet de confirmer le départ puis le retour du véhicule.',
        ),
      ],
      tip:
          'Une réservation terminée passe dans l’historique après confirmation du retour.',
    ),
    AppUsageHelpTopic.immediateDeparture => const _GuideContent(
      title: 'Guide du départ immédiat',
      intro:
          'Ce parcours est prévu pour prendre un véhicule disponible tout de suite.',
      steps: [
        _GuideStepData(
          icon: Icons.location_on_outlined,
          title: 'Choisir le site',
          body:
              'Sélectionnez d’abord le site de départ pour afficher uniquement les véhicules disponibles à cet endroit.',
        ),
        _GuideStepData(
          icon: Icons.directions_car_outlined,
          title: 'Choisir le véhicule',
          body:
              'Prenez un véhicule libre dans la liste. Si aucun véhicule n’apparaît, essayez un autre site ou réservez plus tard.',
        ),
        _GuideStepData(
          icon: Icons.schedule,
          title: 'Indiquer le retour prévu',
          body:
              'Choisissez l’heure de retour estimée. Elle doit rester après l’heure actuelle et avant le prochain créneau réservé.',
        ),
        _GuideStepData(
          icon: Icons.play_circle_outline,
          title: 'Valider',
          body:
              'La validation crée la réservation et démarre le trajet. Le retour devra ensuite être confirmé dans l’application.',
        ),
      ],
      tip:
          'Si la validation échoue, le véhicule a peut-être été réservé entre-temps.',
    ),
    AppUsageHelpTopic.profile => const _GuideContent(
      title: 'Guide du profil',
      intro:
          'Cette page regroupe vos informations de compte et vos préférences locales.',
      steps: [
        _GuideStepData(
          icon: Icons.person_outline,
          title: 'Informations',
          body:
              'Vérifiez votre identité, votre pôle et les sites auxquels vous êtes rattaché.',
        ),
        _GuideStepData(
          icon: Icons.notifications_none,
          title: 'Notifications',
          body:
              'Activez ou désactivez les notifications locales selon vos besoins.',
        ),
        _GuideStepData(
          icon: Icons.privacy_tip_outlined,
          title: 'Données personnelles',
          body:
              'Consultez les informations RGPD et les droits liés à l’utilisation de Wheello.',
        ),
      ],
      tip:
          'Si une information de compte est incorrecte, contactez un administrateur.',
    ),
    AppUsageHelpTopic.personalData => const _GuideContent(
      title: 'Guide des données personnelles',
      intro:
          'Cette page explique quelles données sont utilisées dans Wheello et pourquoi.',
      steps: [
        _GuideStepData(
          icon: Icons.info_outline,
          title: 'Finalité',
          body:
              'Les données servent à gérer les réservations, trajets, constats, signalements et notifications.',
        ),
        _GuideStepData(
          icon: Icons.folder_outlined,
          title: 'Données concernées',
          body:
              'Les informations listées décrivent les données nécessaires au fonctionnement de l’application.',
        ),
        _GuideStepData(
          icon: Icons.contact_support_outlined,
          title: 'Vos droits',
          body:
              'Pour exercer vos droits, passez par le contact interne indiqué par votre structure.',
        ),
      ],
      tip:
          'Cette page est informative : elle ne modifie pas vos réservations ni vos paramètres.',
    ),
  };
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.step});

  final _GuideStepData step;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.body,
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

class _GuideTip extends StatelessWidget {
  const _GuideTip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            color: AppColors.maintenance,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideContent {
  const _GuideContent({
    required this.title,
    required this.intro,
    required this.steps,
    this.tip,
  });

  final String title;
  final String intro;
  final List<_GuideStepData> steps;
  final String? tip;
}

class _GuideStepData {
  const _GuideStepData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
