import 'package:flutter/material.dart';

import '../models/reservation.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';
import 'availability_calendar.dart';

class ReservationBandCalendar extends StatelessWidget {
  const ReservationBandCalendar({
    super.key,
    required this.month,
    required this.reservations,
    required this.canGoToPreviousMonth,
    this.canGoToNextMonth = true,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final List<FleetReservation> reservations;
  final bool canGoToPreviousMonth;
  final bool canGoToNextMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

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
            mainAxisSpacing: 10,
            crossAxisSpacing: 0,
            childAspectRatio: 0.82,
            children: [
              for (var index = 0; index < leadingEmptyDays; index++)
                const _ReservationCalendarDay(day: null, bands: []),
              for (var day = 1; day <= daysInMonth; day++)
                _ReservationCalendarDay(
                  day: day,
                  bands: _bandsForDay(DateTime(month.year, month.month, day)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<_ReservationBand> _bandsForDay(DateTime day) {
    final date = _dateOnly(day);
    final bands = <_ReservationBand>[];

    for (final reservation in reservations) {
      if (reservation.status == ReservationStatus.completed) {
        continue;
      }

      final start = _dateOnly(reservation.startAt);
      final end = _dateOnly(reservation.endAt);

      if (date.isBefore(start) || date.isAfter(end)) {
        continue;
      }

      bands.add(
        _ReservationBand(
          startsToday: _sameDay(date, start),
          endsToday: _sameDay(date, end),
          startsAt: reservation.startAt,
          id: reservation.id,
        ),
      );
    }

    bands.sort((first, second) {
      final startComparison = first.startsAt.compareTo(second.startsAt);
      if (startComparison != 0) {
        return startComparison;
      }
      return first.id.compareTo(second.id);
    });

    return bands;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _ReservationCalendarDay extends StatelessWidget {
  const _ReservationCalendarDay({required this.day, required this.bands});

  final int? day;
  final List<_ReservationBand> bands;

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final primaryBand = bands.isEmpty ? null : bands.first;
    final secondaryBands = primaryBand == null
        ? <_ReservationBand>[]
        : bands.skip(1).take(1).toList();
    final hiddenCount = primaryBand == null
        ? 0
        : bands.length - 1 - secondaryBands.length;

    return Semantics(
      label: _semanticLabel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (primaryBand != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 32,
              child: _ReservationBandHighlight(band: primaryBand),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 32,
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: primaryBand == null
                      ? AppColors.onSurface
                      : AppColors.primary,
                  fontWeight: primaryBand == null
                      ? FontWeight.w600
                      : FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final band in secondaryBands)
                  _ReservationBandSegment(band: band),
                if (hiddenCount > 0)
                  Text(
                    '+$hiddenCount',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _semanticLabel {
    if (bands.isEmpty) {
      return 'Jour $day, aucune réservation';
    }

    return 'Jour $day, ${bands.length} réservation${bands.length > 1 ? 's' : ''}';
  }
}

class _ReservationBandHighlight extends StatelessWidget {
  const _ReservationBandHighlight({required this.band});

  final _ReservationBand band;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: band.startsToday ? 4 : 0,
        right: band.endsToday ? 4 : 0,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(band.startsToday ? 999 : 0),
          right: Radius.circular(band.endsToday ? 999 : 0),
        ),
      ),
    );
  }
}

class _ReservationBandSegment extends StatelessWidget {
  const _ReservationBandSegment({required this.band});

  final _ReservationBand band;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      margin: EdgeInsets.only(
        left: band.startsToday ? 5 : 0,
        right: band.endsToday ? 5 : 0,
        bottom: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(band.startsToday ? 999 : 0),
          right: Radius.circular(band.endsToday ? 999 : 0),
        ),
      ),
    );
  }
}

class _ReservationBand {
  const _ReservationBand({
    required this.startsToday,
    required this.endsToday,
    required this.startsAt,
    required this.id,
  });

  final bool startsToday;
  final bool endsToday;
  final DateTime startsAt;
  final String id;
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
