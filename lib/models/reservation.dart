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
      ReservationStatus.pickupToday => ReservationAction.details,
      ReservationStatus.returnToday => ReservationAction.details,
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
    this.hasOpenConstat = false,
    this.hasClosedConstat = false,
    this.isTerminated = false,
    this.returnedAt,
  });

  static const editLockDelay = Duration(hours: 24);
  static const pickupFormLeadTime = Duration(hours: 1);
  static const returnFormLeadTime = Duration(hours: 1);
  static const shortNoticeCancelDelay = Duration(hours: 1);
  static const departureReminderDelay = Duration(minutes: 30);
  static const returnReminderDelay = Duration(minutes: 30);

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
  final bool hasOpenConstat;
  final bool hasClosedConstat;
  final bool isTerminated;
  final DateTime? returnedAt;

  bool get isInHistory {
    return isTerminated || status == ReservationStatus.completed;
  }

  DateTime get effectiveEndAt {
    final actualReturn = returnedAt;
    if ((!isTerminated && !hasClosedConstat) || actualReturn == null) {
      return endAt;
    }

    return actualReturn.isBefore(endAt) ? actualReturn : endAt;
  }

  FleetReservation copyWith({
    ReservationStatus? status,
    bool? hasOpenConstat,
    bool? hasClosedConstat,
    bool? isTerminated,
    DateTime? returnedAt,
  }) {
    return FleetReservation(
      id: id,
      vehicle: vehicle,
      location: location,
      startAt: startAt,
      endAt: endAt,
      startLabel: startLabel,
      endLabel: endLabel,
      status: status ?? this.status,
      expectedStartMileage: expectedStartMileage,
      createdAt: createdAt,
      hasOpenConstat: hasOpenConstat ?? this.hasOpenConstat,
      hasClosedConstat: hasClosedConstat ?? this.hasClosedConstat,
      isTerminated: isTerminated ?? this.isTerminated,
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }

  bool canBeEditedAt(DateTime now) {
    return now.isBefore(startAt.subtract(editLockDelay));
  }

  bool canBeCancelledAt(DateTime now) {
    if (isInHistory || hasOpenConstat || hasClosedConstat) {
      return false;
    }

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
    return !canBeEditedAt(now) && canOpenPickupFormAt(now);
  }

  bool canOpenPickupFormAt(DateTime now) {
    return !isInHistory &&
        !hasOpenConstat &&
        !hasClosedConstat &&
        !now.isBefore(startAt.subtract(pickupFormLeadTime));
  }

  bool shouldCreateDepartureReminderAt(DateTime now) {
    return !isInHistory &&
        !hasOpenConstat &&
        !hasClosedConstat &&
        !now.isBefore(startAt.add(departureReminderDelay));
  }

  bool shouldShowReturnActionAt(DateTime _) {
    return !isInHistory && hasOpenConstat && !hasClosedConstat;
  }

  bool canOpenReturnFormAt(DateTime now) {
    return shouldShowReturnActionAt(now);
  }

  bool shouldCreateReturnReminderAt(DateTime now) {
    return !isInHistory &&
        hasOpenConstat &&
        !hasClosedConstat &&
        !now.isBefore(endAt.add(returnReminderDelay));
  }
}
