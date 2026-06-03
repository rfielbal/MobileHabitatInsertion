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
  const BookingsScreen({super.key, this.refreshVersion = 0});

  final int refreshVersion;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _fleetApiService = FleetApiService();
  late Future<List<FleetReservation>> _reservationsFuture;
  late final DateTime _minimumCalendarMonth;
  late DateTime _calendarMonth;
  bool _showHistory = false;

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
                final upcomingCount = allReservations
                    .where(
                      (reservation) =>
                          reservation.status != ReservationStatus.completed,
                    )
                    .length;
                final reservations = allReservations.where((reservation) {
                  return _showHistory
                      ? reservation.status == ReservationStatus.completed
                      : reservation.status != ReservationStatus.completed;
                }).toList();

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
                          onPrimaryAction: () => _openReservation(reservation),
                          onEdit: () => _editReservation(reservation),
                          onCancel: () => _cancelReservation(reservation),
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

    if (reservation.shouldShowDepartureActionAt(now) ||
        reservation.status == ReservationStatus.pickupToday) {
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
                _reloadReservations();
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
                _reloadReservations();
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
            _reloadReservations();
          }
        });
  }

  void _reloadReservations() {
    setState(() {
      _reservationsFuture = _fetchReservations();
    });
  }

  Future<List<FleetReservation>> _fetchReservations() async {
    final reservations = await _fleetApiService.fetchReservations();
    await NotificationStore.upsertDepartureReminders(
      reservations,
      DateTime.now(),
    );
    return reservations;
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
            _reloadReservations();
          }
        });
  }

  Future<void> _cancelReservation(FleetReservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: Text(
          'Confirmer l’annulation de la réservation du ${reservation.startLabel} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _fleetApiService.deleteReservation(reservation);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Réservation annulée')));
      _reloadReservations();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Annulation impossible : $e')));
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
    required this.onPrimaryAction,
    required this.onEdit,
    required this.onCancel,
  });

  final FleetReservation reservation;
  final DateTime now;
  final VoidCallback onPrimaryAction;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isCompleted = reservation.status == ReservationStatus.completed;

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
                label: reservation.status.label,
                color: _statusColor(reservation.status),
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
                    onPressed: onEdit,
                    child: const Text('Modifier'),
                  ),
                ],
                if (reservation.canBeCancelledAt(now)) ...[
                  OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Annuler'),
                  ),
                ],
                FilledButton(
                  onPressed: onPrimaryAction,
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
    if (reservation.shouldShowDepartureActionAt(now) ||
        status == ReservationStatus.pickupToday) {
      return 'Départ';
    }

    return switch (status) {
      ReservationStatus.pickupToday => 'Départ',
      ReservationStatus.returnToday => 'Retour véhicule',
      ReservationStatus.upcoming => 'Détails',
      ReservationStatus.completed => '',
    };
  }

  Color _statusColor(ReservationStatus status) {
    return switch (status) {
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
