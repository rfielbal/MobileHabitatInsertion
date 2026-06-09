import '../models/reservation.dart';
import '../models/vehicle.dart';

const reservationTurnaroundDuration = Duration(hours: 1);

Set<int> userUnavailableReservationDaysForMonth({
  required List<FleetReservation> reservations,
  required DateTime month,
  String? excludedReservationId,
}) {
  final days = <int>{};

  for (final reservation in reservations) {
    if (reservation.id == excludedReservationId || reservation.isInHistory) {
      continue;
    }

    days.addAll(
      occupiedReservationDaysForMonth(
        startAt: reservation.startAt,
        endAt: reservation.endAt,
        month: month,
      ),
    );
  }

  return days;
}

Set<int> occupiedReservationDaysForMonth({
  required DateTime startAt,
  required DateTime endAt,
  required DateTime month,
}) {
  if (!startAt.isBefore(endAt)) {
    return const {};
  }

  final days = <int>{};
  var current = DateTime(startAt.year, startAt.month, startAt.day);
  final lastOccupiedInstant = endAt.subtract(const Duration(microseconds: 1));
  final end = DateTime(
    lastOccupiedInstant.year,
    lastOccupiedInstant.month,
    lastOccupiedInstant.day,
  );

  while (!current.isAfter(end)) {
    if (current.year == month.year && current.month == month.month) {
      days.add(current.day);
    }

    current = current.add(const Duration(days: 1));
  }

  return days;
}

bool reservationPeriodContainsUnavailableDayForMonth({
  required DateTime startAt,
  required DateTime endAt,
  required DateTime month,
  required Map<int, AvailabilityStatus> availabilityByDay,
  Set<int> userUnavailableDays = const {},
  Set<int> ignoredDays = const {},
}) {
  return _containsUnavailableDay(
    days: occupiedReservationDaysForMonth(
      startAt: startAt,
      endAt: endAt,
      month: month,
    ),
    availabilityByDay: availabilityByDay,
    userUnavailableDays: userUnavailableDays,
    ignoredDays: ignoredDays,
  );
}

bool userHasOverlappingReservation({
  required List<FleetReservation> reservations,
  required DateTime startAt,
  required DateTime endAt,
  String? excludedReservationId,
}) {
  if (!startAt.isBefore(endAt)) {
    return false;
  }

  for (final reservation in reservations) {
    if (reservation.id == excludedReservationId || reservation.isInHistory) {
      continue;
    }

    if (reservationPeriodsOverlap(
      firstStartAt: startAt,
      firstEndAt: endAt,
      secondStartAt: reservation.startAt,
      secondEndAt: reservation.endAt,
    )) {
      return true;
    }
  }

  return false;
}

bool reservationPeriodsOverlap({
  required DateTime firstStartAt,
  required DateTime firstEndAt,
  required DateTime secondStartAt,
  required DateTime secondEndAt,
  Duration minimumTurnaround = Duration.zero,
}) {
  return firstStartAt.isBefore(secondEndAt.add(minimumTurnaround)) &&
      secondStartAt.isBefore(firstEndAt.add(minimumTurnaround));
}

bool _containsUnavailableDay({
  required Set<int> days,
  required Map<int, AvailabilityStatus> availabilityByDay,
  required Set<int> userUnavailableDays,
  required Set<int> ignoredDays,
}) {
  for (final day in days) {
    if (ignoredDays.contains(day)) {
      continue;
    }

    final status = availabilityByDay[day] ?? AvailabilityStatus.free;
    if (userUnavailableDays.contains(day) || !status.canStartReservation) {
      return true;
    }
  }

  return false;
}
