import 'package:flutter/material.dart';

import '../../data/notification_store.dart';
import '../../models/app_notification.dart';
import '../../models/reservation.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _fleetApiService = FleetApiService();
  String? _resolvingReservationId;

  @override
  void initState() {
    super.initState();
    NotificationStore.refresh();
  }

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
                NotificationStore.loading,
                NotificationStore.error,
              ]),
              builder: (context, _) {
                final notifications = NotificationStore.items.value;
                final readIds = NotificationStore.readIds.value;
                final isLoading = NotificationStore.loading.value;
                final error = NotificationStore.error.value;

                if (isLoading && notifications.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    if (error != null) ...[
                      _NotificationsError(
                        message: 'Impossible de synchroniser les notifications',
                        onRetry: NotificationStore.refresh,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (notifications.isEmpty)
                      const _EmptyNotifications()
                    else
                      for (final notification in notifications) ...[
                        _NotificationCard(
                          notification: notification,
                          read: readIds.contains(notification.id),
                          resolving:
                              _resolvingReservationId ==
                              notification.reservationId,
                          onTap: () => _openNotification(notification),
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

  Future<void> _markAsRead(AppNotification notification) async {
    try {
      await NotificationStore.markAsRead(notification.id);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lecture impossible : $e')));
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!NotificationStore.isUnstartedReservationAction(notification)) {
      await _markAsRead(notification);
      return;
    }

    final reservationId = notification.reservationId;
    if (reservationId == null || reservationId.trim().isEmpty) {
      await _markAsRead(notification);
      return;
    }

    if (_resolvingReservationId != null) {
      return;
    }

    setState(() {
      _resolvingReservationId = reservationId;
    });

    try {
      await NotificationStore.markAsRead(notification.id);
      final reservations = await _fleetApiService.fetchReservations();
      final reservation = _findReservationById(reservations, reservationId);

      if (!mounted) {
        return;
      }

      if (reservation == null ||
          reservation.hasOpenConstat ||
          reservation.isInHistory) {
        await NotificationStore.clearUnstartedReservationReminder(
          reservationId,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cette réservation est déjà traitée.')),
        );
        return;
      }

      final choice = await showDialog<_UnstartedReservationChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Réservation non lancée'),
          content: Text(
            'La réservation de ${reservation.vehicle.name} devait commencer à ${_timeLabel(reservation.startAt)}. Voulez-vous la maintenir ou l’annuler ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(_UnstartedReservationChoice.cancel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_UnstartedReservationChoice.maintain),
              child: const Text('Maintenir'),
            ),
          ],
        ),
      );

      if (choice == null || !mounted) {
        return;
      }

      switch (choice) {
        case _UnstartedReservationChoice.maintain:
          await NotificationStore.maintainUnstartedReservation(reservation.id);
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Réservation maintenue')),
          );
          break;
        case _UnstartedReservationChoice.cancel:
          await _fleetApiService.deleteReservation(reservation);
          await NotificationStore.clearUnstartedReservationReminder(
            reservation.id,
          );
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Réservation annulée')));
          break;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action impossible : $e')));
    } finally {
      if (mounted) {
        setState(() {
          _resolvingReservationId = null;
        });
      }
    }
  }

  FleetReservation? _findReservationById(
    List<FleetReservation> reservations,
    String reservationId,
  ) {
    for (final reservation in reservations) {
      if (reservation.id == reservationId) {
        return reservation;
      }
    }

    return null;
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    try {
      await NotificationStore.delete(notification.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification supprimée : ${notification.title}'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Suppression impossible : $e')));
    }
  }
}

enum _UnstartedReservationChoice { maintain, cancel }

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.read,
    required this.resolving,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final bool read;
  final bool resolving;
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
        child: const Icon(Icons.delete_outline, color: AppColors.onPrimary),
      ),
      onDismissed: (_) => onDelete(),
      child: AppCard(
        opacity: read ? 0.7 : 1,
        onTap: resolving ? null : onTap,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.timeLabel,
                          style: const TextStyle(
                            color: AppColors.outline,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (NotificationStore.isUnstartedReservationAction(
                        notification,
                      ))
                        TextButton.icon(
                          onPressed: resolving ? null : onTap,
                          icon: resolving
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.tune_outlined, size: 18),
                          label: Text(resolving ? 'Chargement' : 'Gérer'),
                        ),
                    ],
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

String _timeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.sync_problem, color: AppColors.maintenance),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
