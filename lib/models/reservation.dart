import 'vehicle.dart';

enum ReservationAction { pickup, returnVehicle, details, none }

enum ReservationStatus { pickupToday, returnToday, upcoming, completed }

extension ReservationStatusX on ReservationStatus {
  String get label {
    return switch (this) {
      ReservationStatus.pickupToday => "Aujourd'hui",
      ReservationStatus.returnToday => 'Retour aujourd’hui',
      ReservationStatus.upcoming => 'À venir',
      ReservationStatus.completed => 'Terminée',
    };
  }

  ReservationAction get action {
    return switch (this) {
      ReservationStatus.pickupToday => ReservationAction.pickup,
      ReservationStatus.returnToday => ReservationAction.returnVehicle,
      ReservationStatus.upcoming => ReservationAction.details,
      ReservationStatus.completed => ReservationAction.none,
    };
  }
}

class FleetReservation {
  const FleetReservation({
    required this.id,
    required this.vehicle,
    required this.location,
    required this.startLabel,
    required this.endLabel,
    required this.status,
  });

  final String id;
  final Vehicle vehicle;
  final String location;
  final String startLabel;
  final String endLabel;
  final ReservationStatus status;
}
