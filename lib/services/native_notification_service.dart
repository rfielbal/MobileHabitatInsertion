import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/app_notification.dart';

abstract class NativeNotificationSink {
  Future<void> initialize();

  Future<bool> notificationsEnabled();

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
  static const _androidNotificationIcon = 'ic_stat_wheello';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<NativeNotificationTapIntent?> tapIntent = ValueNotifier(
    null,
  );

  bool _initialized = false;
  bool _timeZonesInitialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_androidNotificationIcon),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      _initialized = true;
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        _handleNotificationResponse(launchResponse);
      }
    } on MissingPluginException {
      // Le plugin natif n'est pas disponible pendant certains tests/hot restarts.
    }
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();

    try {
      final androidPlugin = _androidPlugin;
      final androidGranted = await androidPlugin
          ?.requestNotificationsPermission();
      if (androidPlugin != null) {
        final exactGranted = androidGranted == false
            ? false
            : await _requestExactAlarmsPermission(androidPlugin);
        return (androidGranted ?? true) && exactGranted;
      }

      final iosGranted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      return androidGranted ?? iosGranted ?? await notificationsEnabled();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> notificationsEnabled() async {
    await initialize();

    try {
      final androidPlugin = _androidPlugin;
      if (androidPlugin != null) {
        final androidEnabled = await androidPlugin.areNotificationsEnabled();
        final exactEnabled = await androidPlugin
            .canScheduleExactNotifications();
        return (androidEnabled ?? true) && (exactEnabled ?? true);
      }

      final iosSettings = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();

      return iosSettings?.isEnabled ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
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
      await _zonedScheduleNotification(
        notification,
        scheduledUtc: scheduledUtc,
        badgeCount: badgeCount,
        androidScheduleMode: await _androidScheduleMode(),
      );
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      if (error.code == 'exact_alarms_not_permitted') {
        return _scheduleInexactly(
          notification,
          scheduledUtc: scheduledUtc,
          badgeCount: badgeCount,
        );
      }

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

  void consumeTapIntent(NativeNotificationTapIntent intent) {
    if (tapIntent.value == intent) {
      tapIntent.value = null;
    }
  }

  NotificationDetails _details({required int badgeCount}) {
    return NotificationDetails(
      android: const AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        icon: _androidNotificationIcon,
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

  void _handleNotificationResponse(NotificationResponse response) {
    final intent = NativeNotificationTapIntent.fromPayload(
      response.payload,
      fallbackNotificationId: response.id,
    );
    if (intent == null) {
      return;
    }

    tapIntent.value = intent;
  }

  void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) {
      return;
    }

    timezone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  Future<bool> _requestExactAlarmsPermission(
    AndroidFlutterLocalNotificationsPlugin androidPlugin,
  ) async {
    try {
      final canScheduleExact = await androidPlugin
          .canScheduleExactNotifications();
      if (canScheduleExact == false) {
        return await androidPlugin.requestExactAlarmsPermission() ?? false;
      }
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final androidPlugin = _androidPlugin;
    if (androidPlugin == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    try {
      final canScheduleExact = await androidPlugin
          .canScheduleExactNotifications();
      if (canScheduleExact == false) {
        return AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } on MissingPluginException {
      return AndroidScheduleMode.exactAllowWhileIdle;
    } on PlatformException {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<bool> _scheduleInexactly(
    AppNotification notification, {
    required DateTime scheduledUtc,
    required int badgeCount,
  }) async {
    try {
      await _zonedScheduleNotification(
        notification,
        scheduledUtc: scheduledUtc,
        badgeCount: badgeCount,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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

  Future<void> _zonedScheduleNotification(
    AppNotification notification, {
    required DateTime scheduledUtc,
    required int badgeCount,
    required AndroidScheduleMode androidScheduleMode,
  }) {
    return _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: timezone.TZDateTime.from(scheduledUtc, timezone.UTC),
      notificationDetails: _details(badgeCount: badgeCount),
      androidScheduleMode: androidScheduleMode,
      payload: _payload(notification),
    );
  }
}

class NativeNotificationTapIntent {
  const NativeNotificationTapIntent({
    required this.notificationId,
    this.reservationId,
  });

  final int notificationId;
  final String? reservationId;

  static NativeNotificationTapIntent? fromPayload(
    String? payload, {
    int? fallbackNotificationId,
  }) {
    final parts = payload?.split(':') ?? const <String>[];
    var notificationId = fallbackNotificationId;
    String? reservationId;

    if (parts.length >= 2 && parts.first == 'notification') {
      notificationId = int.tryParse(parts[1]) ?? notificationId;
    }

    final reservationIndex = parts.indexOf('reservation');
    if (reservationIndex >= 0 && reservationIndex + 1 < parts.length) {
      reservationId = parts.sublist(reservationIndex + 1).join(':').trim();
      if (reservationId.isEmpty) {
        reservationId = null;
      }
    }

    if (notificationId == null) {
      return null;
    }

    return NativeNotificationTapIntent(
      notificationId: notificationId,
      reservationId: reservationId,
    );
  }
}
