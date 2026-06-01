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
            AnimatedBuilder(
              animation: Listenable.merge([
                NotificationStore.items,
                NotificationStore.readIds,
              ]),
              builder: (context, _) {
                final notifications = NotificationStore.items.value;
                final readIds = NotificationStore.readIds.value;

                if (notifications.isEmpty) {
                  return const _EmptyNotifications();
                }

                return Column(
                  children: [
                    for (final notification in notifications) ...[
                      _NotificationCard(
                        notification: notification,
                        read: readIds.contains(notification.id),
                        onTap: () =>
                            NotificationStore.markAsRead(notification.id),
                        onDelete: () => _deleteNotification(notification),
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

  void _deleteNotification(AppNotification notification) {
    NotificationStore.delete(notification.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notification supprimée : ${notification.title}')),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.read,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool read;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: AppCard(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (!read) ...[
                        const SizedBox(width: 8),
                        Container(
                          height: 9,
                          width: 9,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: 'Supprimer la notification',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minHeight: 32,
                          minWidth: 32,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.outline,
                        onPressed: onDelete,
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
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: const [
            Icon(
              Icons.notifications_off_outlined,
              color: AppColors.onSurfaceVariant,
              size: 36,
            ),
            SizedBox(height: 12),
            Text(
              'Aucune notification',
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Les alertes supprimées ne sont plus affichées ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
