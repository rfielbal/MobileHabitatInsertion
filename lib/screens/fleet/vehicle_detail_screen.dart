import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../models/vehicle.dart';
import '../../services/api_exception.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/reservation_calendar_days.dart';
import '../../utils/reservation_time_constraints.dart';
import '../../widgets/app_card.dart';
import '../../widgets/availability_calendar.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/known_issues_card.dart';
import '../../widgets/remote_vehicle_image.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _fleetApiService = FleetApiService();
  late final DateTime _minimumCalendarMonth;
  late DateTime _calendarMonth;
  late Map<int, AvailabilityStatus> _availabilityByDay;
  Map<int, VehicleAvailabilitySuggestion> _availabilitySuggestionsByDay =
      const {};
  Set<int> _userUnavailableDays = const {};
  List<FleetReservation> _userReservations = const [];
  DateTime? _startDate;
  DateTime? _endDate;
  late TimeOfDay _startTime;
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String? _calendarError;
  bool _availabilityLoading = true;
  String? _availabilityError;
  bool _isSubmitting = false;
  int _availabilityRequestVersion = 0;

  bool get _canBook =>
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
    _calendarMonth = _minimumCalendarMonth;
    _availabilityByDay = Map<int, AvailabilityStatus>.of(
      widget.vehicle.availabilityByDay,
    );
    _startTime = _defaultStartTime();
    _loadAvailability();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.vehicle.name)),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: _isSubmitting ? 'Réservation...' : 'Réserver ce véhicule',
              icon: Icons.event_available,
              onPressed: _canBook ? _bookVehicle : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _VehicleHero(vehicle: widget.vehicle),
          const SizedBox(height: 24),
          _VehicleInformation(vehicle: widget.vehicle),
          const SizedBox(height: 24),
          KnownIssuesCard(issues: widget.vehicle.knownIssues),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Disponibilité',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _showAvailabilityHelp,
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Aide'),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          const Center(
            child: Text(
              '1er clic : Départ | 2ème clic : Retour',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
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
          const SizedBox(height: 18),
          _BookingSummary(
            startDate: _startDate,
            endDate: _endDate,
            startTime: _startTime,
            endTime: _endTime,
            onPickStartTime: () => _pickTime(isStart: true),
            onPickEndTime: () => _pickTime(isStart: false),
          ),
          const SizedBox(height: 8),
          const Text(
            'La réservation peut couvrir une journée complète, y compris 00:00 → 00:00 si nécessaire.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _showAvailabilityHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => const _AvailabilityHelpDialog(),
    );
  }

  void _selectDay(int day) {
    final status = _availabilityByDay[day] ?? AvailabilityStatus.free;
    final selectedDate = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      day,
    );

    if (_isBeforeToday(selectedDate)) {
      setState(() {
        _calendarError = 'Les dates passées ne sont pas sélectionnables';
      });
      return;
    }

    if (!status.canStartReservation) {
      setState(() {
        _calendarError = 'Cette date n’est pas disponible';
      });
      return;
    }

    setState(() {
      if (_startDate == null || _endDate != null) {
        _startDate = selectedDate;
        _endDate = null;
        _startTime = _suggestedStartTimeForDate(selectedDate);
      } else if (selectedDate.isBefore(_startDate!)) {
        final previousStartDate = _startDate!;
        _endDate = _startDate;
        _startDate = selectedDate;
        _startTime = _suggestedStartTimeForDate(selectedDate);
        _endTime = _suggestedEndTimeForDate(previousStartDate);
      } else {
        _endDate = selectedDate;
        _endTime = _suggestedEndTimeForDate(selectedDate);
      }

      _calendarError = _selectedPeriodError();
    });
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
      return 'La date de début doit être avant la date de retour';
    }

    if (startAt.isBefore(DateTime.now())) {
      return 'L’heure de départ est déjà passée';
    }

    final startTimeError = _startTimeConstraintError(startAt);
    if (startTimeError != null) {
      return startTimeError;
    }

    final endTimeError = _endTimeConstraintError(endAt);
    if (endTimeError != null) {
      return endTimeError;
    }

    if (_visibleRangeContainsUnavailableDay(startAt: startAt, endAt: endAt)) {
      return 'La période contient une date réservée, en maintenance ou déjà occupée';
    }

    return null;
  }

  String? _startTimeConstraintError(DateTime startAt) {
    if (reservationStartViolatesEarliestStart(
      startAt: startAt,
      suggestionsByDay: _availabilitySuggestionsForDate(startAt),
    )) {
      return 'Le départ doit être au moins 1 h après le retour précédent';
    }

    return null;
  }

  String? _endTimeConstraintError(DateTime endAt) {
    if (reservationEndViolatesLatestEnd(
      endAt: endAt,
      suggestionsByDay: _availabilitySuggestionsForDate(endAt),
      userReservations: _userReservations,
    )) {
      return 'Le retour doit être au moins 1 h avant le prochain départ';
    }

    return null;
  }

  bool _visibleRangeContainsUnavailableDay({
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return reservationPeriodContainsUnavailableDayForMonth(
          startAt: startAt,
          endAt: endAt,
          month: _calendarMonth,
          availabilityByDay: _availabilityByDay,
        ) ||
        userHasOverlappingReservation(
          reservations: _userReservations,
          startAt: startAt,
          endAt: endAt,
        );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);

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

    final date = isStart ? _startDate : _endDate;
    final pickedAt = date == null ? null : _dateTimeWithTime(date, picked);
    String? constraintError;
    if (pickedAt != null) {
      constraintError = isStart
          ? _startTimeConstraintError(pickedAt)
          : _endTimeConstraintError(pickedAt);
    }

    if (constraintError != null && date != null) {
      setState(() {
        if (isStart) {
          _startTime = _suggestedStartTimeForDate(date);
        } else {
          _endTime = _suggestedEndTimeForDate(date);
        }
        _calendarError = constraintError;
      });
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_startDate != null &&
            _endDate != null &&
            _sameCalendarDay(_startDate!, _endDate!)) {
          _endTime = _suggestedEndTimeForDate(_endDate!);
        }
      } else {
        _endTime = picked;
      }
      if (_startDate != null && _endDate != null) {
        _calendarError = _selectedPeriodError();
      }
    });
  }

  Future<void> _bookVehicle() async {
    final startAt = _selectedDateTime(_startDate, _startTime);
    final endAt = _selectedDateTime(_endDate, _endTime);

    if (startAt == null || endAt == null || !startAt.isBefore(endAt)) {
      setState(() {
        _calendarError = 'La date de début doit être avant la date de retour';
      });
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

      await _fleetApiService.createReservation(
        vehicle: widget.vehicle,
        startAt: startAt,
        endAt: endAt,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${widget.vehicle.name} réservé')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _calendarError = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _calendarError = 'Réservation impossible : $e';
      });
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
      final availability = await _fleetApiService
          .fetchVehicleAvailabilityDetailsForMonth(
            vehicle: widget.vehicle,
            month: requestedMonth,
          );
      final reservations = await _fleetApiService.fetchReservations();
      final userUnavailableDays = userUnavailableReservationDaysForMonth(
        reservations: reservations,
        month: requestedMonth,
      );

      if (!mounted || requestVersion != _availabilityRequestVersion) {
        return;
      }

      setState(() {
        _availabilityByDay = availability.availabilityByDay;
        _availabilitySuggestionsByDay = availability.suggestionsByDay;
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
      _availabilitySuggestionsByDay = const {};
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
      _availabilitySuggestionsByDay = const {};
      _userUnavailableDays = const {};
      _calendarError = null;
      _availabilityError = null;
    });

    _loadAvailability();
  }

  bool _isBeforeCurrentMonth(DateTime month) {
    return month.year < _minimumCalendarMonth.year ||
        (month.year == _minimumCalendarMonth.year &&
            month.month < _minimumCalendarMonth.month);
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
      )) {
        return true;
      }

      final availabilityStartAt = startAt.subtract(
        reservationTurnaroundDuration,
      );
      final availabilityEndAt = endAt.add(reservationTurnaroundDuration);

      return !(await _fleetApiService.isVehicleAvailableForPeriod(
        vehicle: widget.vehicle,
        startAt: availabilityStartAt,
        endAt: availabilityEndAt,
      ));
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
    final availabilityStartAt = startAt.subtract(reservationTurnaroundDuration);
    final availabilityEndAt = endAt.add(reservationTurnaroundDuration);
    var month = DateTime(availabilityStartAt.year, availabilityStartAt.month);
    final lastMonth = DateTime(availabilityEndAt.year, availabilityEndAt.month);
    final reservations = await _fleetApiService.fetchReservations();

    if (userHasOverlappingReservation(
      reservations: reservations,
      startAt: startAt,
      endAt: endAt,
    )) {
      return true;
    }

    while (!month.isAfter(lastMonth)) {
      final availabilityByDay = await _fleetApiService
          .fetchVehicleAvailabilityForMonth(
            vehicle: widget.vehicle,
            month: month,
          );
      final userUnavailableDays = userUnavailableReservationDaysForMonth(
        reservations: reservations,
        month: month,
      );

      if (reservationPeriodContainsUnavailableDayForMonth(
        startAt: availabilityStartAt,
        endAt: availabilityEndAt,
        month: month,
        availabilityByDay: availabilityByDay,
        userUnavailableDays: userUnavailableDays,
      )) {
        return true;
      }

      month = DateTime(month.year, month.month + 1);
    }

    return false;
  }

  DateTime? _selectedDateTime(DateTime? date, TimeOfDay time) {
    if (date == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  TimeOfDay _defaultStartTime() {
    return TimeOfDay.fromDateTime(
      DateTime.now().add(reservationTurnaroundDuration),
    );
  }

  TimeOfDay _suggestedStartTimeForDate(DateTime date) {
    return TimeOfDay.fromDateTime(
      suggestedReservationStartAt(
        date: date,
        suggestionsByDay: _availabilitySuggestionsForDate(date),
      ),
    );
  }

  TimeOfDay _suggestedEndTimeForDate(DateTime date) {
    return TimeOfDay.fromDateTime(
      suggestedReservationEndAt(
        date: date,
        suggestionsByDay: _availabilitySuggestionsForDate(date),
        startAt: _selectedDateTime(_startDate, _startTime),
        userReservations: _userReservations,
      ),
    );
  }

  Map<int, VehicleAvailabilitySuggestion> _availabilitySuggestionsForDate(
    DateTime date,
  ) {
    if (date.year != _calendarMonth.year ||
        date.month != _calendarMonth.month) {
      return const {};
    }

    return _availabilitySuggestionsByDay;
  }

  DateTime _dateTimeWithTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  bool _sameCalendarDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
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

  bool _isBeforeToday(DateTime date) {
    final now = DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }
}

class _VehicleInformation extends StatelessWidget {
  const _VehicleInformation({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _InformationRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Numéro véhicule',
            value: vehicle.internalNumber,
          ),
          const Divider(height: 24),
          _InformationRow(
            icon: Icons.location_city_outlined,
            label: 'Site',
            value: vehicle.site,
          ),
          const Divider(height: 24),
          _InformationRow(
            icon: Icons.local_parking_outlined,
            label: 'Stationnement',
            value: vehicle.parkingDescription,
          ),
          const Divider(height: 24),
          _InformationRow(
            icon: Icons.speed_outlined,
            label: 'Kilométrage connu',
            value: '${vehicle.currentMileage} km',
          ),
          if (vehicle.energyType.usesFuelLevel) ...[
            const Divider(height: 24),
            _InformationRow(
              icon: Icons.local_gas_station_outlined,
              label: 'Carburant',
              value: vehicle.fuelLevelLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
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
        Icon(icon, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailabilityHelpDialog extends StatelessWidget {
  const _AvailabilityHelpDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Comprendre le calendrier'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvailabilityHelpItem(
              color: AppColors.available,
              title: 'Libre',
              description:
                  'Le véhicule peut être réservé sur cette journée, selon les heures sélectionnées.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.partial,
              title: 'Partiel',
              description:
                  'Une partie de la journée est déjà prise. L’application propose automatiquement la première heure possible ou la dernière heure de retour possible.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.error,
              title: 'Réservé',
              description:
                  'Le véhicule est réservé sur toute la journée et ne peut pas être sélectionné.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.maintenance,
              title: 'Maintenance',
              description:
                  'Le véhicule est indisponible administrativement et ne peut pas être réservé.',
            ),
            _AvailabilityHelpItem(
              color: AppColors.userUnavailable,
              title: 'Indisponible pour moi',
              description:
                  'Vous avez déjà une réservation active sur cette période, même si le véhicule affiché est libre.',
            ),
            SizedBox(height: 8),
            Text(
              'Sélection : appuyez une première fois pour choisir le départ, puis une deuxième fois pour choisir le retour. Les jours passés ne sont pas sélectionnables.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Compris'),
        ),
      ],
    );
  }
}

class _AvailabilityHelpItem extends StatelessWidget {
  const _AvailabilityHelpItem({
    required this.color,
    required this.title,
    required this.description,
  });

  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 12,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
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

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Stack(
            children: [
              RemoteVehicleImage(
                imageUrl: vehicle.imageUrl,
                height: 190,
                width: double.infinity,
                borderRadius: 16,
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.ev_station,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.energyType.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Spec(
                  icon: Icons.airline_seat_recline_normal,
                  label: vehicle.seats,
                ),
                const _Divider(),
                _Spec(icon: Icons.settings, label: vehicle.transmission),
                const _Divider(),
                _Spec(icon: Icons.speed, label: vehicle.energyInfo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 36, width: 1, color: AppColors.outlineVariant);
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
