import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

const visibleAvailabilityStatuses = [
  AvailabilityStatus.free,
  AvailabilityStatus.partial,
  AvailabilityStatus.reserved,
  AvailabilityStatus.maintenance,
];

class AvailabilityLegend extends StatelessWidget {
  const AvailabilityLegend({
    super.key,
    this.statuses = visibleAvailabilityStatuses,
    this.includeUserUnavailable = false,
  });

  final List<AvailabilityStatus> statuses;
  final bool includeUserUnavailable;

  @override
  Widget build(BuildContext context) {
    final vehicleItems = [
      for (final status in statuses)
        _LegendItem(color: status.color, label: status.label),
    ];

    if (!includeUserUnavailable) {
      return _LegendItemsWrap(items: vehicleItems);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendSection(title: 'Voiture', items: vehicleItems),
        const SizedBox(height: 10),
        const _LegendSection(
          title: 'Mes disponibilités',
          items: [
            _LegendItem(
              color: AppColors.userUnavailable,
              label: 'Indisponible',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendSection extends StatelessWidget {
  const _LegendSection({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        _LegendItemsWrap(items: items),
      ],
    );
  }
}

class _LegendItemsWrap extends StatelessWidget {
  const _LegendItemsWrap({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 14, runSpacing: 10, children: items);
  }
}

class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({
    super.key,
    required this.month,
    required this.availabilityByDay,
    this.userUnavailableDays = const {},
    this.startDay,
    this.endDay,
    this.rangeStartDate,
    this.rangeEndDate,
    this.minimumSelectableDate,
    this.canGoToPreviousMonth = false,
    this.canGoToNextMonth = true,
    this.canGoToCurrentMonth = false,
    this.onPreviousMonth,
    this.onNextMonth,
    this.onCurrentMonth,
    this.onDaySelected,
  });

  final DateTime month;
  final Map<int, AvailabilityStatus> availabilityByDay;
  final Set<int> userUnavailableDays;
  final int? startDay;
  final int? endDay;
  final DateTime? rangeStartDate;
  final DateTime? rangeEndDate;
  final DateTime? minimumSelectableDate;
  final bool canGoToPreviousMonth;
  final bool canGoToNextMonth;
  final bool canGoToCurrentMonth;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onCurrentMonth;
  final ValueChanged<int>? onDaySelected;

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
                onPressed: canGoToPreviousMonth ? onPreviousMonth : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${monthLabel(month.month)} ${month.year}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Mois actuel',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minHeight: 32,
                      minWidth: 32,
                    ),
                    iconSize: 18,
                    onPressed: canGoToCurrentMonth ? onCurrentMonth : null,
                    icon: const Icon(Icons.today_outlined),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Mois suivant',
                onPressed: canGoToNextMonth ? onNextMonth : null,
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
                const _CalendarDay(
                  label: '',
                  disabled: true,
                  isSelected: false,
                  isInRange: false,
                  status: AvailabilityStatus.free,
                  isUserUnavailable: false,
                  onTap: null,
                ),
              for (var day = 1; day <= daysInMonth; day++)
                _CalendarDay(
                  label: '$day',
                  disabled: _isBeforeMinimumSelectableDate(day),
                  isSelected: _isSelected(day),
                  isInRange: _isInRange(day),
                  status: availabilityByDay[day] ?? AvailabilityStatus.free,
                  isUserUnavailable: userUnavailableDays.contains(day),
                  onTap:
                      onDaySelected == null ||
                          _isBeforeMinimumSelectableDate(day)
                      ? null
                      : () => onDaySelected?.call(day),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isInRange(int day) {
    final date = DateTime(month.year, month.month, day);

    if (rangeStartDate != null && rangeEndDate != null) {
      final start = _dateOnly(rangeStartDate!);
      final end = _dateOnly(rangeEndDate!);
      return !date.isBefore(start) && !date.isAfter(end);
    }

    if (startDay == null || endDay == null) {
      return false;
    }
    return day >= startDay! && day <= endDay!;
  }

  bool _isSelected(int day) {
    final date = DateTime(month.year, month.month, day);

    if (rangeStartDate != null || rangeEndDate != null) {
      return _sameDayOrFalse(date, rangeStartDate) ||
          _sameDayOrFalse(date, rangeEndDate);
    }

    return day == startDay || day == endDay;
  }

  bool _isBeforeMinimumSelectableDate(int day) {
    final minimum = minimumSelectableDate;
    if (minimum == null) {
      return false;
    }

    return DateTime(month.year, month.month, day).isBefore(_dateOnly(minimum));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _sameDayOrFalse(DateTime date, DateTime? other) {
    return other != null &&
        date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
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
    required this.isUserUnavailable,
    required this.onTap,
  });

  final String label;
  final bool disabled;
  final bool isSelected;
  final bool isInRange;
  final AvailabilityStatus status;
  final bool isUserUnavailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRangeSelectable =
        isInRange &&
        !isSelected &&
        !isUserUnavailable &&
        status.canStartReservation;
    final isHighlighted = isSelected || isRangeSelectable;
    final backgroundColor = disabled
        ? AppColors.transparent
        : isHighlighted
        ? AppColors.primary
        : isUserUnavailable
        ? AppColors.userUnavailable.withValues(alpha: 0.18)
        : status.color.withValues(alpha: 0.18);
    final borderColor = disabled || isHighlighted
        ? AppColors.transparent
        : isUserUnavailable
        ? AppColors.userUnavailable.withValues(alpha: 0.6)
        : status.color.withValues(alpha: 0.52);
    final textColor = disabled
        ? AppColors.outlineVariant
        : isHighlighted
        ? AppColors.onPrimary
        : isUserUnavailable
        ? AppColors.userUnavailable
        : AppColors.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: disabled ? null : onTap,
      child: Container(
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
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String dayLabel(DateTime month, int? day) {
  if (day == null) {
    return '--';
  }
  final date = DateTime(month.year, month.month, day);
  const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  return '${weekDays[date.weekday - 1]} $day ${monthLabel(month.month)}';
}

String dateLabel(DateTime? date) {
  if (date == null) {
    return '--';
  }
  const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  return '${weekDays[date.weekday - 1]} ${date.day} ${monthLabel(date.month)}';
}

String monthLabel(int month) {
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
