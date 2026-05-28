import 'package:flutter/material.dart';

import '../../data/notification_store.dart';
import '../../models/app_notification.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Dernières alertes',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<Set<int>>(
              valueListenable: NotificationStore.readIds,
              builder: (context, readIds, _) {
                return Column(
                  children: [
                    for (final notification in NotificationStore.items) ...[
                      _NotificationCard(
                        notification: notification,
                        read: readIds.contains(notification.id),
                        onTap: () {
                          NotificationStore.markAsRead(notification.id);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.read,
    required this.onTap,
  });

  final AppNotification notification;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      opacity: read ? 0.7 : 1,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: notification.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(notification.icon, color: notification.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!read)
                      Container(
                        height: 9,
                        width: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notification.timeLabel,
                  style: const TextStyle(
                    color: AppColors.outline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
