import 'package:flutter/material.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    required this.color,
  });

  final int id;
  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final Color color;
}
