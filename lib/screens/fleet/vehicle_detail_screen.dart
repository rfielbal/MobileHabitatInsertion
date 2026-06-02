import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../services/api_exception.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
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
  final DateTime _calendarMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  late Map<int, AvailabilityStatus> _availabilityByDay;
  int? _startDay;
  int? _endDay;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String? _calendarError;
  bool _availabilityLoading = true;
  String? _availabilityError;
  bool _isSubmitting = false;

  bool get _canBook =>
      _startDay != null &&
      _endDay != null &&
      _calendarError == null &&
      !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _availabilityByDay = Map<int, AvailabilityStatus>.of(
      widget.vehicle.availabilityByDay,
    );
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
          const Text(
            'Disponibilité',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const _AvailabilityLegend(),
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
          _CalendarCard(
            month: _calendarMonth,
            availabilityByDay: _availabilityByDay,
            startDay: _startDay,
            endDay: _endDay,
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
            month: _calendarMonth,
            startDay: _startDay,
            endDay: _endDay,
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

  void _selectDay(int day) {
    final status = _availabilityByDay[day] ?? AvailabilityStatus.free;

    if (!status.canStartReservation) {
      setState(() {
        _calendarError = 'Cette date n’est pas disponible';
      });
      return;
    }

    setState(() {
      if (_startDay == null || _endDay != null) {
        _startDay = day;
        _endDay = null;
      } else if (day < _startDay!) {
        _endDay = _startDay;
        _startDay = day;
      } else {
        _endDay = day;
      }

      _calendarError = _rangeContainsUnavailableDay()
          ? 'La période contient une date réservée ou en maintenance'
          : null;
    });
  }

  bool _rangeContainsUnavailableDay() {
    if (_startDay == null || _endDay == null) {
      return false;
    }

    for (var day = _startDay!; day <= _endDay!; day++) {
      final status = _availabilityByDay[day] ?? AvailabilityStatus.free;
      if (!status.canStartReservation) {
        return true;
      }
    }

    return false;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _bookVehicle() async {
    final startAt = _selectedDateTime(_startDay, _startTime);
    final endAt = _selectedDateTime(_endDay, _endTime);

    if (startAt == null || endAt == null || !startAt.isBefore(endAt)) {
      setState(() {
        _calendarError = 'La date de début doit être avant la date de retour';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
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
    setState(() {
      _availabilityLoading = true;
      _availabilityError = null;
    });

    try {
      final availabilityByDay = await _fleetApiService
          .fetchVehicleAvailabilityForMonth(
            vehicle: widget.vehicle,
            month: _calendarMonth,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _availabilityByDay = availabilityByDay;
        _availabilityLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _availabilityLoading = false;
        _availabilityError =
            'Disponibilités non synchronisées, seules les données connues sont affichées.';
      });
    }
  }

  DateTime? _selectedDateTime(int? day, TimeOfDay time) {
    if (day == null) {
      return null;
    }

    return DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      day,
      time.hour,
      time.minute,
    );
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

class _AvailabilityLegend extends StatelessWidget {
  const _AvailabilityLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: AvailabilityStatus.values.map((status) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 10,
              width: 10,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.availabilityByDay,
    required this.startDay,
    required this.endDay,
    required this.onDaySelected,
  });

  final DateTime month;
  final Map<int, AvailabilityStatus> availabilityByDay;
  final int? startDay;
  final int? endDay;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmptyDays = firstDay.weekday - 1;

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Mois précédent',
                onPressed: null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_monthLabel(month.month)} ${month.year}',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(
                tooltip: 'Mois suivant',
                onPressed: null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekDayLabel('L'),
              _WeekDayLabel('M'),
              _WeekDayLabel('M'),
              _WeekDayLabel('J'),
              _WeekDayLabel('V'),
              _WeekDayLabel('S'),
              _WeekDayLabel('D'),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 1.08,
            children: [
              for (var index = 0; index < leadingEmptyDays; index++)
                _CalendarDay(
                  label: '',
                  disabled: true,
                  isSelected: false,
                  isInRange: false,
                  status: AvailabilityStatus.free,
                  onTap: null,
                ),
              for (var day = 1; day <= daysInMonth; day++)
                _CalendarDay(
                  label: '$day',
                  disabled: false,
                  isSelected: day == startDay || day == endDay,
                  isInRange: _isInRange(day),
                  status: availabilityByDay[day] ?? AvailabilityStatus.free,
                  onTap: () => onDaySelected(day),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isInRange(int day) {
    if (startDay == null || endDay == null) {
      return false;
    }
    return day >= startDay! && day <= endDay!;
  }
}

class _WeekDayLabel extends StatelessWidget {
  const _WeekDayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.outline, fontSize: 12),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.label,
    required this.disabled,
    required this.isSelected,
    required this.isInRange,
    required this.status,
    required this.onTap,
  });

  final String label;
  final bool disabled;
  final bool isSelected;
  final bool isInRange;
  final AvailabilityStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvailabilityMarker = status != AvailabilityStatus.free;
    final backgroundColor = isInRange
        ? AppColors.primary
        : hasAvailabilityMarker
        ? status.color.withValues(alpha: 0.16)
        : Colors.transparent;
    final borderColor = isInRange || !hasAvailabilityMarker
        ? Colors.transparent
        : status.color.withValues(alpha: 0.45);
    final textColor = disabled
        ? AppColors.outlineVariant
        : isInRange
        ? Colors.white
        : AppColors.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: disabled ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected || hasAvailabilityMarker
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
          if (!disabled && !isInRange && !hasAvailabilityMarker)
            Positioned(
              bottom: 2,
              child: Container(
                height: 5,
                width: 5,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.month,
    required this.startDay,
    required this.endDay,
    required this.startTime,
    required this.endTime,
    required this.onPickStartTime,
    required this.onPickEndTime,
  });

  final DateTime month;
  final int? startDay;
  final int? endDay;
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
                  value: _dayLabel(month, startDay),
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
                  value: _dayLabel(month, endDay),
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

String _dayLabel(DateTime month, int? day) {
  if (day == null) {
    return '-';
  }
  final date = DateTime(month.year, month.month, day);
  const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  return '${weekDays[date.weekday - 1]} $day ${_monthLabel(month.month)}';
}

String _monthLabel(int month) {
  const months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  return months[month - 1];
}
