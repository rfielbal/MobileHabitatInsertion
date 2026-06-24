import 'package:flutter/material.dart';

enum AppNotificationAction {
  none,
  resolveUnstartedReservation,
  openMobileUpdate,
}

extension AppNotificationActionParsing on AppNotificationAction {
  static AppNotificationAction fromPayloadValue(String? value) {
    return switch (value) {
      'resolveUnstartedReservation' =>
        AppNotificationAction.resolveUnstartedReservation,
      'openMobileUpdate' => AppNotificationAction.openMobileUpdate,
      _ => AppNotificationAction.none,
    };
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    required this.color,
    this.action = AppNotificationAction.none,
    this.reservationId,
  });

  final int id;
  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final Color color;
  final AppNotificationAction action;
  final String? reservationId;
}
