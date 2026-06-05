import 'package:flutter/material.dart';

import '../../data/notification_store.dart';
import '../../models/reservation.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_top_bar.dart';
import '../../widgets/reservation_band_calendar.dart';
import '../../widgets/status_chip.dart';
import 'notifications_screen.dart';
import 'pickup_screen.dart';
import 'reservation_edit_screen.dart';
import 'return_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    this.refreshVersion = 0,
    this.onReservationChanged,
  });

  final int refreshVersion;
  final VoidCallback? onReservationChanged;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _fleetApiService = FleetApiService();
  late Future<List<FleetReservation>> _reservationsFuture;
  late final DateTime _minimumCalendarMonth;
  late DateTime _calendarMonth;
  bool _showHistory = false;
  String? _deletingReservationId;
  final _locallyStartedReservationIds = <String>{};
  final _locallyCompletedReservationIds = <String>{};
  final _locallyDeletedReservationIds = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minimumCalendarMonth = DateTime(now.year, now.month);
    _calendarMonth = _minimumCalendarMonth;
    _reservationsFuture = _fetchReservations();
  }

  @override
  void didUpdateWidget(covariant BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _reloadReservations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandTopBar(
        onNotificationsPressed: () => _openNotifications(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Mes Réservations',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<FleetReservation>>(
              future: _reservationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return _BookingsError(onRetry: _reloadReservations);
                }

                final allReservations = snapshot.data ?? const [];
                final upcomingReservations = allReservations
                    .where((reservation) => !reservation.isInHistory)
                    .toList();
                final historyReservations = allReservations
                    .where((reservation) => reservation.isInHistory)
                    .toList();
                final upcomingCount = upcomingReservations.length;
                final reservations = _showHistory
                    ? historyReservations
                    : upcomingReservations;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReservationCalendarSection(
                      month: _calendarMonth,
                      reservations: allReservations,
                      canGoToPreviousMonth: _canGoToPreviousCalendarMonth,
                      canGoToCurrentMonth: _canGoToCurrentCalendarMonth,
                      onPreviousMonth: () => _changeCalendarMonth(-1),
                      onNextMonth: () => _changeCalendarMonth(1),
                      onCurrentMonth: _goToCurrentCalendarMonth,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        ChoiceChip(
                          selected: !_showHistory,
                          label: Text('À venir ($upcomingCount)'),
                          onSelected: (_) =>
                              setState(() => _showHistory = false),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: !_showHistory
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          selected: _showHistory,
                          label: const Text('Historique'),
                          onSelected: (_) =>
                              setState(() => _showHistory = true),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _showHistory
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (reservations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Aucune réservation à afficher',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      for (final reservation in reservations) ...[
                        _ReservationCard(
                          reservation: reservation,
                          now: DateTime.now(),
                          isDeleting: _deletingReservationId == reservation.id,
                          onPrimaryAction: () => _openReservation(reservation),
                          onEdit: () => _editReservation(reservation),
                          onDelete: () => _deleteReservation(reservation),
                        ),
                        const SizedBox(height: 14),
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

  void _openReservation(FleetReservation reservation) {
    final now = DateTime.now();

    if (reservation.shouldShowReturnActionAt(now)) {
      _openReturnForm(reservation);
      return;
    }

    if (reservation.shouldShowDepartureActionAt(now)) {
      _openPickupForm(reservation);
      return;
    }

    switch (reservation.status.action) {
      case ReservationAction.pickup:
        _openPickupForm(reservation);
      case ReservationAction.returnVehicle:
        Navigator.of(context)
            .push<bool>(
              MaterialPageRoute<bool>(
                builder: (context) =>
                    ReturnVehicleScreen(reservation: reservation),
              ),
            )
            .then((updated) {
              if (updated ?? false) {
                _handleReservationChanged();
              }
            });
      case ReservationAction.details:
        Navigator.of(context)
            .push<bool>(
              MaterialPageRoute<bool>(
                builder: (context) =>
                    VehicleDetailScreen(vehicle: reservation.vehicle),
              ),
            )
            .then((updated) {
              if (updated ?? false) {
                _handleReservationChanged();
              }
            });
      case ReservationAction.none:
        break;
    }
  }

  void _editReservation(FleetReservation reservation) {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) =>
                ReservationEditScreen(reservation: reservation),
          ),
        )
        .then((updated) {
          if (updated ?? false) {
            _handleReservationChanged();
          }
        });
  }

  void _reloadReservations() {
    setState(() {
      _reservationsFuture = _fetchReservations();
    });
  }

  void _handleReservationChanged() {
    _reloadReservations();
    widget.onReservationChanged?.call();
  }

  Future<List<FleetReservation>> _fetchReservations() async {
    final reservations = await _fleetApiService.fetchReservations();
    await NotificationStore.syncServerReservations(
      reservations,
      locallyDeletedReservationIds: _locallyDeletedReservationIds,
    );

    final reservationIds = reservations
        .map((reservation) => reservation.id)
        .toSet();
    _locallyDeletedReservationIds.removeWhere(
      (reservationId) => !reservationIds.contains(reservationId),
    );
    final apiCompletedReservationIds = reservations
        .where(
          (reservation) => reservation.status == ReservationStatus.completed,
        )
        .map((reservation) => reservation.id)
        .toSet();

    _locallyStartedReservationIds.removeWhere(
      (reservationId) =>
          !reservationIds.contains(reservationId) ||
          apiCompletedReservationIds.contains(reservationId),
    );
    _locallyStartedReservationIds.removeAll(_locallyCompletedReservationIds);
    _locallyCompletedReservationIds.removeWhere(
      (reservationId) =>
          !reservationIds.contains(reservationId) ||
          apiCompletedReservationIds.contains(reservationId),
    );

    final reservationsWithLocalState = [
      for (final reservation in reservations)
        if (_locallyCompletedReservationIds.contains(reservation.id))
          reservation.copyWith(
            status: ReservationStatus.completed,
            hasOpenConstat: false,
            hasClosedConstat: true,
          )
        else if (_locallyStartedReservationIds.contains(reservation.id) &&
            reservation.status != ReservationStatus.completed)
          reservation.copyWith(hasOpenConstat: true)
        else
          reservation,
    ];
    await NotificationStore.upsertDepartureReminders(
      reservationsWithLocalState,
      DateTime.now(),
    );
    return reservationsWithLocalState;
  }

  void _openPickupForm(FleetReservation reservation) {
    final now = DateTime.now();

    if (!reservation.canOpenPickupFormAt(now)) {
      final availableAt = reservation.startAt.subtract(
        FleetReservation.pickupFormLeadTime,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Le formulaire de départ sera disponible à ${_timeLabel(availableAt)}.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => PickupScreen(reservation: reservation),
          ),
        )
        .then((updated) {
          if (updated ?? false) {
            _locallyStartedReservationIds.add(reservation.id);
            _handleReservationChanged();
          }
        });
  }

  void _openReturnForm(FleetReservation reservation) {
    final now = DateTime.now();

    if (!reservation.canOpenReturnFormAt(now)) {
      final availableAt = reservation.endAt.subtract(
        FleetReservation.returnFormLeadTime,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Le formulaire de retour sera disponible à ${_timeLabel(availableAt)}.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => ReturnVehicleScreen(reservation: reservation),
          ),
        )
        .then((updated) {
          if (updated ?? false) {
            _locallyStartedReservationIds.remove(reservation.id);
            _locallyCompletedReservationIds.add(reservation.id);
            _handleReservationChanged();
          }
        });
  }

  Future<void> _deleteReservation(FleetReservation reservation) async {
    if (_deletingReservationId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la réservation'),
        content: Text(
          'Confirmer la suppression de la réservation du ${reservation.startLabel} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _deletingReservationId = reservation.id;
    });

    try {
      await _fleetApiService.deleteReservation(reservation);
      if (!mounted) {
        return;
      }
      _locallyDeletedReservationIds.add(reservation.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Réservation supprimée')));
      _handleReservationChanged();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Suppression impossible : $e')));
    } finally {
      if (mounted) {
        setState(() {
          _deletingReservationId = null;
        });
      }
    }
  }

  bool get _canGoToPreviousCalendarMonth {
    return _calendarMonth.year > _minimumCalendarMonth.year ||
        (_calendarMonth.year == _minimumCalendarMonth.year &&
            _calendarMonth.month > _minimumCalendarMonth.month);
  }

  bool get _canGoToCurrentCalendarMonth {
    return _calendarMonth.year != _minimumCalendarMonth.year ||
        _calendarMonth.month != _minimumCalendarMonth.month;
  }

  void _changeCalendarMonth(int offset) {
    final nextMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + offset,
    );

    if (nextMonth.year < _minimumCalendarMonth.year ||
        (nextMonth.year == _minimumCalendarMonth.year &&
            nextMonth.month < _minimumCalendarMonth.month)) {
      return;
    }

    setState(() {
      _calendarMonth = nextMonth;
    });
  }

  void _goToCurrentCalendarMonth() {
    if (!_canGoToCurrentCalendarMonth) {
      return;
    }

    setState(() {
      _calendarMonth = _minimumCalendarMonth;
    });
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.now,
    required this.isDeleting,
    required this.onPrimaryAction,
    required this.onEdit,
    required this.onDelete,
  });

  final FleetReservation reservation;
  final DateTime now;
  final bool isDeleting;
  final VoidCallback onPrimaryAction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = reservation.isInHistory;

    return AppCard(
      opacity: isCompleted ? 0.78 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reservation.vehicle.internalNumber} • ${reservation.vehicle.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.pin_drop_outlined,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reservation.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: _statusLabel(reservation),
                color: _statusColor(reservation),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DateBlock(
                  label: 'Départ',
                  value: reservation.startLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateBlock(label: 'Retour', value: reservation.endLabel),
              ),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (reservation.canBeEditedAt(now)) ...[
                  OutlinedButton(
                    onPressed: isDeleting ? null : onEdit,
                    child: const Text('Modifier'),
                  ),
                ],
                if (reservation.canBeCancelledAt(now)) ...[
                  OutlinedButton(
                    onPressed: isDeleting ? null : onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: Text(isDeleting ? 'Suppression...' : 'Supprimer'),
                  ),
                ],
                FilledButton(
                  onPressed: isDeleting ? null : onPrimaryAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: Text(_primaryActionLabel(reservation.status)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _primaryActionLabel(ReservationStatus status) {
    if (reservation.shouldShowReturnActionAt(now)) {
      return 'Retour';
    }

    if (reservation.shouldShowDepartureActionAt(now)) {
      return 'Départ';
    }

    return switch (status) {
      ReservationStatus.pickupToday => 'Détails',
      ReservationStatus.returnToday => 'Détails',
      ReservationStatus.upcoming => 'Détails',
      ReservationStatus.completed => '',
    };
  }

  String _statusLabel(FleetReservation reservation) {
    if (reservation.hasOpenConstat) {
      return 'Trajet en cours';
    }

    if (reservation.hasClosedConstat) {
      return 'Retour confirmé';
    }

    if (reservation.status == ReservationStatus.returnToday) {
      return 'Départ à confirmer';
    }

    return reservation.status.label;
  }

  Color _statusColor(FleetReservation reservation) {
    if (reservation.hasOpenConstat) {
      return AppColors.primary;
    }

    if (reservation.hasClosedConstat) {
      return AppColors.secondary;
    }

    return switch (reservation.status) {
      ReservationStatus.pickupToday => AppColors.maintenance,
      ReservationStatus.returnToday => AppColors.primary,
      ReservationStatus.upcoming => AppColors.primary,
      ReservationStatus.completed => AppColors.secondary,
    };
  }
}

class _ReservationCalendarSection extends StatelessWidget {
  const _ReservationCalendarSection({
    required this.month,
    required this.reservations,
    required this.canGoToPreviousMonth,
    required this.canGoToCurrentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onCurrentMonth,
  });

  final DateTime month;
  final List<FleetReservation> reservations;
  final bool canGoToPreviousMonth;
  final bool canGoToCurrentMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onCurrentMonth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Calendrier',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ReservationBandCalendar(
          month: month,
          reservations: reservations,
          canGoToPreviousMonth: canGoToPreviousMonth,
          canGoToCurrentMonth: canGoToCurrentMonth,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onCurrentMonth: onCurrentMonth,
        ),
      ],
    );
  }
}

class _BookingsError extends StatelessWidget {
  const _BookingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.onSurfaceVariant,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger les réservations depuis l’API.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.outline,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
        ),
      ],
    );
  }
}
