import '../models/reservation.dart';

List<FleetReservation> reservationsDeletedOnServer({
  required List<FleetReservation> previousReservations,
  required List<FleetReservation> currentReservations,
  Set<String> locallyDeletedReservationIds = const {},
}) {
  final currentIds = currentReservations
      .map((reservation) => reservation.id)
      .toSet();

  return [
    for (final reservation in previousReservations)
      if (!reservation.isInHistory &&
          !currentIds.contains(reservation.id) &&
          !locallyDeletedReservationIds.contains(reservation.id))
        reservation,
  ];
}
