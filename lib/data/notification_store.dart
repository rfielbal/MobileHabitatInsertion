import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/notification_api_service.dart';

class NotificationStore {
  const NotificationStore._();

  static final ValueNotifier<List<AppNotification>> items = ValueNotifier(
    <AppNotification>[],
  );
  static final ValueNotifier<Set<int>> readIds = ValueNotifier(<int>{});
  static final ValueNotifier<bool> loading = ValueNotifier(false);
  static final ValueNotifier<String?> error = ValueNotifier(null);
  static final NotificationApiService _apiService = NotificationApiService();

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
      final payloads = await _apiService.fetchNotifications();
      items.value = payloads.map((payload) => payload.notification).toList();
      readIds.value = {
        for (final payload in payloads)
          if (payload.read) payload.notification.id,
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

    await _apiService.markAsRead(id);
    readIds.value = {...readIds.value, id};
  }

  static Future<void> delete(int id) async {
    await _apiService.deleteNotification(id);
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
