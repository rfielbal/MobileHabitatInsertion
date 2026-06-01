import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../theme/app_colors.dart';

class NotificationStore {
  const NotificationStore._();

  static const _initialItems = [
    AppNotification(
      id: 1,
      title: 'Départ prévu aujourd’hui',
      body: 'Votre réservation Renault Kangoo commence à 09:00.',
      timeLabel: 'Il y a 12 min',
      icon: Icons.event_available,
      color: AppColors.primary,
    ),
    AppNotification(
      id: 2,
      title: 'Alerte administrateur',
      body: 'Vérifiez l’état des pneus avant le départ.',
      timeLabel: 'Hier',
      icon: Icons.warning_amber,
      color: AppColors.maintenance,
    ),
    AppNotification(
      id: 3,
      title: 'Retour véhicule',
      body: 'Pensez à ajouter la vidéo de fin et le kilométrage de retour.',
      timeLabel: 'Lun. 26 Mai',
      icon: Icons.assignment_turned_in_outlined,
      color: AppColors.available,
    ),
  ];

  static final ValueNotifier<List<AppNotification>> items = ValueNotifier(
    List<AppNotification>.of(_initialItems),
  );
  static final ValueNotifier<Set<int>> readIds = ValueNotifier(<int>{});

  static int get unreadCount {
    return items.value.where((item) => !readIds.value.contains(item.id)).length;
  }

  static bool isRead(int id) {
    return readIds.value.contains(id);
  }

  static void markAsRead(int id) {
    if (readIds.value.contains(id)) {
      return;
    }

    readIds.value = {...readIds.value, id};
  }

  static void delete(int id) {
    items.value = [
      for (final item in items.value)
        if (item.id != id) item,
    ];

    if (readIds.value.contains(id)) {
      readIds.value = {
        for (final readId in readIds.value)
          if (readId != id) readId,
      };
    }
  }
}
