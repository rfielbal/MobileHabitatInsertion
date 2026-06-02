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
    required this.startAt,
    required this.endAt,
    required this.startLabel,
    required this.endLabel,
    required this.status,
    required this.expectedStartMileage,
    this.createdAt,
  });

  static const editLockDelay = Duration(hours: 24);
  static const pickupFormLeadTime = Duration(hours: 1);
  static const shortNoticeCancelDelay = Duration(hours: 1);
  static const departureReminderDelay = Duration(minutes: 30);

  final String id;
  final Vehicle vehicle;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final String startLabel;
  final String endLabel;
  final ReservationStatus status;
  final int expectedStartMileage;
  final DateTime? createdAt;

  bool canBeEditedAt(DateTime now) {
    return now.isBefore(startAt.subtract(editLockDelay));
  }

  bool canBeCancelledAt(DateTime now) {
    if (!now.isBefore(startAt)) {
      return false;
    }

    if (canBeEditedAt(now)) {
      return true;
    }

    final creationDate = createdAt;
    if (creationDate == null) {
      return false;
    }

    final shortNoticeReservation =
        startAt.difference(creationDate) < editLockDelay;
    final stillInGracePeriod = !now.isAfter(
      creationDate.add(shortNoticeCancelDelay),
    );

    return shortNoticeReservation && stillInGracePeriod;
  }

  bool shouldShowDepartureActionAt(DateTime now) {
    return status != ReservationStatus.completed &&
        !now.isBefore(startAt.subtract(editLockDelay)) &&
        now.isBefore(startAt);
  }

  bool canOpenPickupFormAt(DateTime now) {
    return !now.isBefore(startAt.subtract(pickupFormLeadTime)) &&
        now.isBefore(endAt);
  }

  bool shouldCreateDepartureReminderAt(DateTime now) {
    return status != ReservationStatus.completed &&
        !now.isBefore(startAt.add(departureReminderDelay)) &&
        now.isBefore(endAt);
  }
}
