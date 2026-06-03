import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_notification.dart';
import '../models/reservation.dart';
import '../services/notification_api_service.dart';
import '../theme/app_colors.dart';

class NotificationStore {
  const NotificationStore._();

  static final ValueNotifier<List<AppNotification>> items = ValueNotifier(
    <AppNotification>[],
  );
  static final ValueNotifier<Set<int>> readIds = ValueNotifier(<int>{});
  static final ValueNotifier<bool> loading = ValueNotifier(false);
  static final ValueNotifier<String?> error = ValueNotifier(null);
  static final NotificationApiService _apiService = NotificationApiService();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _dismissedLocalNotificationsStorageKey =
      'dismissed_local_notification_ids';
  static final Set<int> _dismissedLocalNotificationIds = <int>{};
  static final Set<int> _emittedLocalNotificationIds = <int>{};
  static bool _dismissedLocalNotificationIdsLoaded = false;

  static int get unreadCount {
    return items.value.where((item) => !readIds.value.contains(item.id)).length;
  }

  static bool isRead(int id) {
    return readIds.value.contains(id);
  }

  static Future<void> refresh() async {
    loading.value = true;
    error.value = null;

    try {
      final localNotifications = [
        for (final item in items.value)
          if (_isLocalNotification(item.id)) item,
      ];
      final localReadIds = {
        for (final id in readIds.value)
          if (_isLocalNotification(id)) id,
      };
      final payloads = await _apiService.fetchNotifications();
      items.value = [
        ...payloads.map((payload) => payload.notification),
        ...localNotifications,
      ];
      readIds.value = {
        for (final payload in payloads)
          if (payload.read) payload.notification.id,
        ...localReadIds,
      };
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  static Future<void> markAsRead(int id) async {
    if (readIds.value.contains(id)) {
      return;
    }

    if (_isLocalNotification(id)) {
      readIds.value = {...readIds.value, id};
      return;
    }

    await _apiService.markAsRead(id);
    readIds.value = {...readIds.value, id};
  }

  static Future<void> delete(int id) async {
    if (_isLocalNotification(id)) {
      await _deleteFromLocalState(id);
      return;
    }

    await _apiService.deleteNotification(id);
    await _deleteFromLocalState(id);
  }

  static Future<void> upsertDepartureReminders(
    List<FleetReservation> reservations,
    DateTime now,
  ) async {
    await _ensureDismissedLocalNotificationIdsLoaded();

    final existingLocalIds = {
      for (final item in items.value)
        if (_isLocalNotification(item.id)) item.id,
    };
    final reminders = [
      for (final reservation in reservations)
        if (reservation.shouldCreateDepartureReminderAt(now) &&
            _shouldEmitDepartureReminder(reservation, existingLocalIds))
          AppNotification(
            id: _departureReminderId(reservation),
            title: 'Départ à confirmer',
            body:
                'Le formulaire de départ de ${reservation.vehicle.name} devait être envoyé à ${_timeLabel(reservation.startAt)}.',
            timeLabel: 'Maintenant',
            icon: Icons.assignment_late_outlined,
            color: AppColors.maintenance,
          ),
    ];

    for (final reminder in reminders) {
      _emittedLocalNotificationIds.add(reminder.id);
    }

    final reminderIds = reminders
        .map((notification) => notification.id)
        .toSet();

    items.value = [
      for (final item in items.value)
        if (!_isLocalNotification(item.id) || reminderIds.contains(item.id))
          item,
      for (final reminder in reminders)
        if (!items.value.any((item) => item.id == reminder.id)) reminder,
    ];
  }

  static bool _isLocalNotification(int id) {
    return id < 0;
  }

  static int _departureReminderId(FleetReservation reservation) {
    return -1000000 - reservation.id.hashCode.abs();
  }

  static bool _shouldEmitDepartureReminder(
    FleetReservation reservation,
    Set<int> existingLocalIds,
  ) {
    final id = _departureReminderId(reservation);

    if (_dismissedLocalNotificationIds.contains(id)) {
      return false;
    }

    return existingLocalIds.contains(id) ||
        !_emittedLocalNotificationIds.contains(id);
  }

  static Future<void> _deleteFromLocalState(int id) async {
    if (_isLocalNotification(id)) {
      await _ensureDismissedLocalNotificationIdsLoaded();
      _dismissedLocalNotificationIds.add(id);
      await _persistDismissedLocalNotificationIds();
    }

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

  static Future<void> _ensureDismissedLocalNotificationIdsLoaded() async {
    if (_dismissedLocalNotificationIdsLoaded) {
      return;
    }

    try {
      final storedIds = await _storage.read(
        key: _dismissedLocalNotificationsStorageKey,
      );

      if (storedIds != null && storedIds.isNotEmpty) {
        final decodedIds = jsonDecode(storedIds);

        if (decodedIds is List) {
          _dismissedLocalNotificationIds.addAll(
            decodedIds.whereType<num>().map((id) => id.toInt()),
          );
        }
      }
    } catch (_) {
      // Une erreur de stockage local ne doit pas empêcher l'affichage des données API.
    } finally {
      _dismissedLocalNotificationIdsLoaded = true;
    }
  }

  static Future<void> _persistDismissedLocalNotificationIds() async {
    final sortedIds = _dismissedLocalNotificationIds.toList()..sort();

    try {
      await _storage.write(
        key: _dismissedLocalNotificationsStorageKey,
        value: jsonEncode(sortedIds),
      );
    } catch (_) {
      // La suppression reste appliquée en mémoire même si la persistance échoue.
    }
  }

  static String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
