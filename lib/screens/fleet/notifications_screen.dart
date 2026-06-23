import 'package:flutter/material.dart';

import '../../data/notification_store.dart';
import '../../models/app_notification.dart';
import '../../models/reservation.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.initialNotificationId,
    this.initialReservationId,
    this.initialAction = AppNotificationAction.none,
  });

  final int? initialNotificationId;
  final String? initialReservationId;
  final AppNotificationAction initialAction;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _fleetApiService = FleetApiService();
  String? _resolvingReservationId;
  bool _handledInitialNotification = false;

  @override
  void initState() {
    super.initState();
    NotificationStore.items.addListener(_tryOpenInitialNotification);
    NotificationStore.loading.addListener(_tryOpenInitialNotification);
    NotificationStore.refresh().whenComplete(_tryOpenInitialNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryOpenInitialNotification();
    });
  }

  @override
  void dispose() {
    NotificationStore.items.removeListener(_tryOpenInitialNotification);
    NotificationStore.loading.removeListener(_tryOpenInitialNotification);
    super.dispose();
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
                        message: error,
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
    await _markNotificationIdAsRead(notification.id);
  }

  Future<void> _markNotificationIdAsRead(int notificationId) async {
    try {
      await NotificationStore.markAsRead(notificationId);
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
      final reservationId = _navigableReservationId(notification);
      if (reservationId != null && mounted) {
        Navigator.of(context).pop(reservationId);
      }
      return;
    }

    final reservationId = notification.reservationId?.trim();
    if (reservationId == null || reservationId.isEmpty) {
      await _markAsRead(notification);
      return;
    }

    await _openUnstartedReservation(
      reservationId,
      notificationId: notification.id,
    );
  }

  Future<void> _openUnstartedReservation(
    String reservationId, {
    int? notificationId,
  }) async {
    if (_resolvingReservationId != null) {
      return;
    }

    setState(() {
      _resolvingReservationId = reservationId;
    });

    try {
      if (notificationId != null) {
        await NotificationStore.markAsRead(notificationId);
      }
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
        builder: (context) =>
            _UnstartedReservationDialog(reservation: reservation),
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
          await NotificationStore.clearReservationReminders(reservation.id);
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

  String? _navigableReservationId(AppNotification notification) {
    final reservationId = notification.reservationId?.trim();
    if (reservationId == null || reservationId.isEmpty) {
      return null;
    }

    if (_isReservationDeletionNotification(notification)) {
      return null;
    }

    return reservationId;
  }

  bool _isReservationDeletionNotification(AppNotification notification) {
    final text = '${notification.title} ${notification.body}'.toLowerCase();
    return (text.contains('réservation') || text.contains('reservation')) &&
        text.contains('supprim');
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

  void _tryOpenInitialNotification() {
    if (_handledInitialNotification || !mounted) {
      return;
    }

    final reservationId = widget.initialReservationId;
    final notificationId = widget.initialNotificationId;
    if (NotificationStore.loading.value) {
      return;
    }

    if (notificationId != null) {
      final notification = _findNotificationById(
        NotificationStore.items.value,
        notificationId,
      );
      if (notification != null) {
        _handledInitialNotification = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _openNotification(notification);
        });
        return;
      }
    }

    final normalizedReservationId = reservationId?.trim();
    if (normalizedReservationId == null || normalizedReservationId.isEmpty) {
      if (notificationId != null) {
        _handledInitialNotification = true;
      }
      return;
    }

    _handledInitialNotification = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      if (widget.initialAction ==
          AppNotificationAction.resolveUnstartedReservation) {
        await _openUnstartedReservation(
          normalizedReservationId,
          notificationId: widget.initialNotificationId,
        );
        return;
      }

      final notificationId = widget.initialNotificationId;
      if (notificationId != null) {
        await _markNotificationIdAsRead(notificationId);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(normalizedReservationId);
    });
  }

  AppNotification? _findNotificationById(
    List<AppNotification> notifications,
    int notificationId,
  ) {
    for (final notification in notifications) {
      if (notification.id == notificationId) {
        return notification;
      }
    }

    return null;
  }
}

enum _UnstartedReservationChoice { maintain, cancel }

class _UnstartedReservationDialog extends StatelessWidget {
  const _UnstartedReservationDialog({required this.reservation});

  final FleetReservation reservation;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pending_actions_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Réservation non lancée',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.vehicle.name,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _ReservationDialogInfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'Départ prévu',
                  value: _timeLabel(reservation.startAt),
                ),
                const SizedBox(height: 6),
                _ReservationDialogInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Site',
                  value: reservation.location,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Voulez-vous maintenir cette réservation ou l’annuler ?',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_UnstartedReservationChoice.maintain),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Maintenir la réservation'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_UnstartedReservationChoice.cancel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler la réservation'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _ReservationDialogInfoRow extends StatelessWidget {
  const _ReservationDialogInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label : ',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
