import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../models/vehicle.dart';
import '../../services/api_exception.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/reservation_calendar_days.dart';
import '../../widgets/app_card.dart';
import '../../widgets/availability_calendar.dart';
import '../../widgets/bottom_action_bar.dart';

class ReservationEditScreen extends StatefulWidget {
  const ReservationEditScreen({super.key, required this.reservation});

  final FleetReservation reservation;

  @override
  State<ReservationEditScreen> createState() => _ReservationEditScreenState();
}

class _ReservationEditScreenState extends State<ReservationEditScreen> {
  final _fleetApiService = FleetApiService();
  late final DateTime _minimumCalendarMonth;
  late DateTime _calendarMonth;
  late Map<int, AvailabilityStatus> _availabilityByDay;
  Set<int> _userUnavailableDays = const {};
  List<FleetReservation> _userReservations = const [];
  DateTime? _startDate;
  DateTime? _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isSubmitting = false;
  bool _availabilityLoading = true;
  String? _calendarError;
  String? _availabilityError;
  int _availabilityRequestVersion = 0;

  bool get _canSave =>
      _startDate != null &&
      _endDate != null &&
      _calendarError == null &&
      !_availabilityLoading &&
      !_isSubmitting;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minimumCalendarMonth = DateTime(now.year, now.month);
    final reservationMonth = DateTime(
      widget.reservation.startAt.year,
      widget.reservation.startAt.month,
    );
    _calendarMonth = _isBeforeCurrentMonth(reservationMonth)
        ? _minimumCalendarMonth
        : reservationMonth;
    _availabilityByDay = const {};
    _startDate = DateTime(
      widget.reservation.startAt.year,
      widget.reservation.startAt.month,
      widget.reservation.startAt.day,
    );
    _endDate = DateTime(
      widget.reservation.endAt.year,
      widget.reservation.endAt.month,
      widget.reservation.endAt.day,
    );
    _startTime = TimeOfDay.fromDateTime(widget.reservation.startAt);
    _endTime = TimeOfDay.fromDateTime(widget.reservation.endAt);
    _loadAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la réservation')),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: 'Annuler',
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              outlined: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BottomActionButton(
              label: _isSubmitting ? 'Enregistrement...' : 'Enregistrer',
              onPressed: _canSave ? _save : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppCard(
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.reservation.vehicle.internalNumber} • ${widget.reservation.vehicle.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.reservation.vehicle.plateNumber} • ${widget.reservation.location}',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nouvelle période',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const AvailabilityLegend(includeUserUnavailable: true),
            if (_availabilityLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_availabilityError != null) ...[
              const SizedBox(height: 12),
              Text(
                _availabilityError!,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            AvailabilityCalendar(
              month: _calendarMonth,
              availabilityByDay: _availabilityByDay,
              userUnavailableDays: _userUnavailableDays,
              rangeStartDate: _startDate,
              rangeEndDate: _endDate,
              minimumSelectableDate: DateTime.now(),
              canGoToPreviousMonth: _canGoToPreviousMonth,
              canGoToCurrentMonth: _canGoToCurrentMonth,
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onCurrentMonth: _goToCurrentMonth,
              onDaySelected: _selectDay,
            ),
            if (_calendarError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _calendarError!,
                        style: const TextStyle(
                          color: AppColors.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _EditBookingSummary(
              startDate: _startDate,
              endDate: _endDate,
              startTime: _startTime,
              endTime: _endTime,
              onPickStartTime: () => _pickTime(isStart: true),
              onPickEndTime: () => _pickTime(isStart: false),
            ),
            const SizedBox(height: 14),
            const Text(
              'Cette modification sera reliée à l’API métier pour vérifier les conflits de réservation.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDay(int day) {
    final status = _availabilityByDay[day] ?? AvailabilityStatus.free;
    final selectedDate = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      day,
    );
    final isOriginalReservationDay = _isOriginalReservationDay(day);

    if (_isBeforeToday(selectedDate)) {
      setState(() {
        _calendarError = 'Les dates passées ne sont pas sélectionnables';
      });
      return;
    }

    if (!isOriginalReservationDay && !status.canStartReservation) {
      setState(() {
        _calendarError = 'Cette date n’est pas disponible';
      });
      return;
    }

    setState(() {
      if (_startDate == null || _endDate != null) {
        _startDate = selectedDate;
        _endDate = null;
      } else if (selectedDate.isBefore(_startDate!)) {
        _endDate = _startDate;
        _startDate = selectedDate;
      } else {
        _endDate = selectedDate;
      }

      _calendarError = _selectedPeriodError();
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked == null || !mounted) {
      return;
    }

    if (_timeWouldBeInPast(isStart: isStart, time: picked)) {
      setState(() {
        _calendarError = isStart
            ? 'L’heure de départ est déjà passée'
            : 'L’heure de retour est déjà passée';
      });
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      if (_startDate != null && _endDate != null) {
        _calendarError = _selectedPeriodError();
      }
    });
  }

  Future<void> _save() async {
    final startAt = _selectedDateTime(_startDate, _startTime);
    final endAt = _selectedDateTime(_endDate, _endTime);

    if (startAt == null || endAt == null || !startAt.isBefore(endAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de départ doit être avant la date de retour'),
        ),
      );
      return;
    }

    final periodError = _reservationPeriodError(startAt: startAt, endAt: endAt);
    if (periodError != null) {
      setState(() {
        _calendarError = periodError;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final unavailable = await _rangeContainsUnavailableDay(
        startAt: startAt,
        endAt: endAt,
      );
      if (unavailable) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isSubmitting = false;
          _calendarError =
              'La période contient une date réservée, en maintenance ou déjà occupée';
        });
        return;
      }

      await _fleetApiService.updateReservation(
        reservation: widget.reservation,
        startAt: startAt,
        endAt: endAt,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Réservation modifiée')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Modification impossible : $e')));
    }
  }

  Future<void> _loadAvailability() async {
    final requestVersion = ++_availabilityRequestVersion;
    final requestedMonth = _calendarMonth;

    setState(() {
      _availabilityLoading = true;
      _availabilityError = null;
    });

    try {
      final availabilityByDay = await _fleetApiService
          .fetchVehicleAvailabilityForMonth(
            vehicle: widget.reservation.vehicle,
            month: requestedMonth,
          );
      final reservations = await _fleetApiService.fetchReservations();
      final userUnavailableDays = userUnavailableReservationDaysForMonth(
        reservations: reservations,
        month: requestedMonth,
        excludedReservationId: widget.reservation.id,
      );

      if (!mounted || requestVersion != _availabilityRequestVersion) {
        return;
      }

      setState(() {
        _availabilityByDay = _withOriginalReservationAvailable(
          availabilityByDay,
          requestedMonth,
        );
        _userUnavailableDays = userUnavailableDays;
        _userReservations = reservations;
        _availabilityLoading = false;
      });
    } catch (_) {
      if (!mounted || requestVersion != _availabilityRequestVersion) {
        return;
      }

      setState(() {
        _availabilityLoading = false;
        _availabilityError =
            'Disponibilités non synchronisées, seules les données connues sont affichées.';
      });
    }
  }

  Map<int, AvailabilityStatus> _withOriginalReservationAvailable(
    Map<int, AvailabilityStatus> availabilityByDay,
    DateTime month,
  ) {
    final result = Map<int, AvailabilityStatus>.of(availabilityByDay);

    for (final day in occupiedReservationDaysForMonth(
      startAt: widget.reservation.startAt,
      endAt: widget.reservation.endAt,
      month: month,
    )) {
      result[day] = AvailabilityStatus.free;
    }

    return result;
  }

  String? _selectedPeriodError() {
    final startAt = _selectedDateTime(_startDate, _startTime);
    final endAt = _selectedDateTime(_endDate, _endTime);

    if (startAt == null || endAt == null) {
      return null;
    }

    return _reservationPeriodError(startAt: startAt, endAt: endAt);
  }

  String? _reservationPeriodError({
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (!startAt.isBefore(endAt)) {
      return 'La date de départ doit être avant la date de retour';
    }

    if (startAt.isBefore(DateTime.now())) {
      return 'L’heure de départ est déjà passée';
    }

    if (_visibleRangeContainsUnavailableDay(startAt: startAt, endAt: endAt)) {
      return 'La période contient une date réservée, en maintenance ou déjà occupée';
    }

    return null;
  }

  bool _visibleRangeContainsUnavailableDay({
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final ignoredDays = occupiedReservationDaysForMonth(
      startAt: widget.reservation.startAt,
      endAt: widget.reservation.endAt,
      month: _calendarMonth,
    );

    return reservationPeriodContainsUnavailableDayForMonth(
          startAt: startAt,
          endAt: endAt,
          month: _calendarMonth,
          availabilityByDay: _availabilityByDay,
          ignoredDays: ignoredDays,
        ) ||
        userHasOverlappingReservation(
          reservations: _userReservations,
          startAt: startAt,
          endAt: endAt,
          excludedReservationId: widget.reservation.id,
        );
  }

  bool get _canGoToPreviousMonth {
    return _calendarMonth.year > _minimumCalendarMonth.year ||
        (_calendarMonth.year == _minimumCalendarMonth.year &&
            _calendarMonth.month > _minimumCalendarMonth.month);
  }

  bool get _canGoToCurrentMonth {
    return _calendarMonth.year != _minimumCalendarMonth.year ||
        _calendarMonth.month != _minimumCalendarMonth.month;
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + offset,
    );

    if (_isBeforeCurrentMonth(nextMonth)) {
      return;
    }

    setState(() {
      _calendarMonth = nextMonth;
      _availabilityByDay = const {};
      _userUnavailableDays = const {};
      _calendarError = null;
      _availabilityError = null;
    });

    _loadAvailability();
  }

  void _goToCurrentMonth() {
    if (!_canGoToCurrentMonth) {
      return;
    }

    setState(() {
      _calendarMonth = _minimumCalendarMonth;
      _availabilityByDay = const {};
      _userUnavailableDays = const {};
      _calendarError = null;
      _availabilityError = null;
    });

    _loadAvailability();
  }

  Future<bool> _rangeContainsUnavailableDay({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      final reservations = await _fleetApiService.fetchReservations();
      if (userHasOverlappingReservation(
        reservations: reservations,
        startAt: startAt,
        endAt: endAt,
        excludedReservationId: widget.reservation.id,
      )) {
        return true;
      }

      for (final period in _availabilityCheckPeriodsOutsideOriginalReservation(
        startAt: startAt,
        endAt: endAt,
      )) {
        final isAvailable = await _fleetApiService.isVehicleAvailableForPeriod(
          vehicle: widget.reservation.vehicle,
          startAt: period.startAt,
          endAt: period.endAt,
        );
        if (!isAvailable) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return _rangeContainsUnavailableDayByMonth(
        startAt: startAt,
        endAt: endAt,
      );
    }
  }

  Future<bool> _rangeContainsUnavailableDayByMonth({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final reservations = await _fleetApiService.fetchReservations();

    if (userHasOverlappingReservation(
      reservations: reservations,
      startAt: startAt,
      endAt: endAt,
      excludedReservationId: widget.reservation.id,
    )) {
      return true;
    }

    for (final period in _availabilityCheckPeriodsOutsideOriginalReservation(
      startAt: startAt,
      endAt: endAt,
    )) {
      var month = DateTime(period.startAt.year, period.startAt.month);
      final lastMonth = DateTime(period.endAt.year, period.endAt.month);

      while (!month.isAfter(lastMonth)) {
        final availabilityByDay = _withOriginalReservationAvailable(
          await _fleetApiService.fetchVehicleAvailabilityForMonth(
            vehicle: widget.reservation.vehicle,
            month: month,
          ),
          month,
        );

        if (reservationPeriodContainsUnavailableDayForMonth(
          startAt: period.startAt,
          endAt: period.endAt,
          month: month,
          availabilityByDay: availabilityByDay,
          ignoredDays: occupiedReservationDaysForMonth(
            startAt: widget.reservation.startAt,
            endAt: widget.reservation.endAt,
            month: month,
          ),
        )) {
          return true;
        }

        month = DateTime(month.year, month.month + 1);
      }
    }

    return false;
  }

  List<({DateTime startAt, DateTime endAt})>
  _availabilityCheckPeriodsOutsideOriginalReservation({
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final originalStartAt = widget.reservation.startAt;
    final originalEndAt = widget.reservation.endAt;
    final periods = <({DateTime startAt, DateTime endAt})>[];

    if (startAt.isBefore(originalStartAt)) {
      final requestedEndAt = endAt.isBefore(originalStartAt)
          ? endAt
          : originalStartAt;
      final checkStartAt = startAt.subtract(reservationTurnaroundDuration);
      final bufferedEndAt = requestedEndAt.add(reservationTurnaroundDuration);
      final checkEndAt = bufferedEndAt.isBefore(originalStartAt)
          ? bufferedEndAt
          : originalStartAt;
      if (checkStartAt.isBefore(checkEndAt)) {
        periods.add((startAt: checkStartAt, endAt: checkEndAt));
      }
    }

    if (endAt.isAfter(originalEndAt)) {
      final requestedStartAt = startAt.isAfter(originalEndAt)
          ? startAt
          : originalEndAt;
      final bufferedStartAt = requestedStartAt.subtract(
        reservationTurnaroundDuration,
      );
      final checkStartAt = bufferedStartAt.isAfter(originalEndAt)
          ? bufferedStartAt
          : originalEndAt;
      final checkEndAt = endAt.add(reservationTurnaroundDuration);
      if (checkStartAt.isBefore(checkEndAt)) {
        periods.add((startAt: checkStartAt, endAt: checkEndAt));
      }
    }

    return periods;
  }

  DateTime? _selectedDateTime(DateTime? date, TimeOfDay time) {
    if (date == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  bool _timeWouldBeInPast({required bool isStart, required TimeOfDay time}) {
    final date = isStart ? _startDate : _endDate;
    if (date == null) {
      return false;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).isBefore(DateTime.now());
  }

  bool _isOriginalReservationDay(int day) {
    return occupiedReservationDaysForMonth(
      startAt: widget.reservation.startAt,
      endAt: widget.reservation.endAt,
      month: _calendarMonth,
    ).contains(day);
  }

  bool _isBeforeCurrentMonth(DateTime month) {
    return month.year < _minimumCalendarMonth.year ||
        (month.year == _minimumCalendarMonth.year &&
            month.month < _minimumCalendarMonth.month);
  }

  bool _isBeforeToday(DateTime date) {
    final now = DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }
}

class _EditBookingSummary extends StatelessWidget {
  const _EditBookingSummary({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.onPickStartTime,
    required this.onPickEndTime,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateSummary(
                  label: 'Départ',
                  value: dateLabel(startDate),
                ),
              ),
              Container(
                height: 34,
                width: 34,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.outline,
                  size: 20,
                ),
              ),
              Expanded(
                child: _DateSummary(
                  label: 'Retour',
                  value: dateLabel(endDate),
                  alignRight: true,
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Heure de départ',
                  value: startTime.format(context),
                  onTap: onPickStartTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeButton(
                  label: 'Heure de retour',
                  value: endTime.format(context),
                  onTap: onPickEndTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSummary extends StatelessWidget {
  const _DateSummary({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.outline,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}
