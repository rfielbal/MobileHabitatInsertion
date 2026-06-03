import '../models/reservation.dart';

Set<int> userUnavailableReservationDaysForMonth({
  required List<FleetReservation> reservations,
  required DateTime month,
  String? excludedReservationId,
}) {
  final days = <int>{};

  for (final reservation in reservations) {
    if (reservation.id == excludedReservationId ||
        reservation.status == ReservationStatus.completed) {
      continue;
    }

    var current = DateTime(
      reservation.startAt.year,
      reservation.startAt.month,
      reservation.startAt.day,
    );
    final end = DateTime(
      reservation.endAt.year,
      reservation.endAt.month,
      reservation.endAt.day,
    );

    while (!current.isAfter(end)) {
      if (current.year == month.year && current.month == month.month) {
        days.add(current.day);
      }

      current = current.add(const Duration(days: 1));
    }
  }

  return days;
}
