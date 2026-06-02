import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

const visibleAvailabilityStatuses = [
  AvailabilityStatus.free,
  AvailabilityStatus.reserved,
  AvailabilityStatus.maintenance,
];

class AvailabilityLegend extends StatelessWidget {
  const AvailabilityLegend({
    super.key,
    this.statuses = visibleAvailabilityStatuses,
  });

  final List<AvailabilityStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: statuses.map((status) {
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

class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({
    super.key,
    required this.month,
    required this.availabilityByDay,
    this.startDay,
    this.endDay,
    this.rangeStartDate,
    this.rangeEndDate,
    this.canGoToPreviousMonth = false,
    this.canGoToNextMonth = true,
    this.onPreviousMonth,
    this.onNextMonth,
    this.onDaySelected,
  });

  final DateTime month;
  final Map<int, AvailabilityStatus> availabilityByDay;
  final int? startDay;
  final int? endDay;
  final DateTime? rangeStartDate;
  final DateTime? rangeEndDate;
  final bool canGoToPreviousMonth;
  final bool canGoToNextMonth;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
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
              Text(
                '${monthLabel(month.month)} ${month.year}',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
                  onTap: null,
                ),
              for (var day = 1; day <= daysInMonth; day++)
                _CalendarDay(
                  label: '$day',
                  disabled: false,
                  isSelected: _isSelected(day),
                  isInRange: _isInRange(day),
                  status: availabilityByDay[day] ?? AvailabilityStatus.free,
                  onTap: onDaySelected == null
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
    final isHighlighted = isSelected || isInRange;
    final backgroundColor = disabled
        ? Colors.transparent
        : isHighlighted
        ? AppColors.primary
        : status.color.withValues(alpha: 0.18);
    final borderColor = disabled || isHighlighted
        ? Colors.transparent
        : status.color.withValues(alpha: 0.52);
    final textColor = disabled
        ? AppColors.outlineVariant
        : isHighlighted
        ? Colors.white
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
