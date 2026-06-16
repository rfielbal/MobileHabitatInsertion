import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/app_notification.dart';

abstract class NativeNotificationSink {
  Future<void> initialize();

  Future<bool> requestPermissions();

  Future<bool> show(AppNotification notification, {required int badgeCount});

  Future<bool> schedule(
    AppNotification notification, {
    required DateTime scheduledAt,
    required int badgeCount,
  });

  Future<void> cancel(int notificationId);
}

class NativeNotificationService implements NativeNotificationSink {
  NativeNotificationService._();

  static final NativeNotificationService instance =
      NativeNotificationService._();

  static const _androidChannelId = 'wheello_reservation_alerts';
  static const _androidChannelName = 'Alertes de réservation';
  static const _androidChannelDescription =
      'Rappels de départ, de retour et de réservation Wheello';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZonesInitialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    } on MissingPluginException {
      // Le plugin natif n'est pas disponible pendant certains tests/hot restarts.
    }
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();

    try {
      final androidGranted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      final iosGranted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      return androidGranted ?? iosGranted ?? true;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> show(
    AppNotification notification, {
    required int badgeCount,
  }) async {
    await initialize();

    try {
      await _plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: _details(badgeCount: badgeCount),
        payload: _payload(notification),
      );
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> schedule(
    AppNotification notification, {
    required DateTime scheduledAt,
    required int badgeCount,
  }) async {
    final scheduledUtc = scheduledAt.toUtc();
    if (!scheduledUtc.isAfter(DateTime.now().toUtc())) {
      return show(notification, badgeCount: badgeCount);
    }

    await initialize();
    _ensureTimeZonesInitialized();

    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: timezone.TZDateTime.from(scheduledUtc, timezone.UTC),
        notificationDetails: _details(badgeCount: badgeCount),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _payload(notification),
      );
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();

    try {
      await _plugin.cancel(id: notificationId);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  NotificationDetails _details({required int badgeCount}) {
    return NotificationDetails(
      android: const AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        channelShowBadge: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        badgeNumber: badgeCount,
      ),
    );
  }

  String _payload(AppNotification notification) {
    final reservationId = notification.reservationId;
    if (reservationId == null || reservationId.trim().isEmpty) {
      return 'notification:${notification.id}';
    }

    return 'notification:${notification.id}:reservation:$reservationId';
  }

  void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) {
      return;
    }

    timezone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
}
