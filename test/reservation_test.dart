import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';

void main() {
  test('reservations can be edited only before the 24 hour lock window', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
    );

    expect(reservation.canBeEditedAt(DateTime(2026, 6, 17, 8, 59)), isTrue);
    expect(reservation.canBeEditedAt(DateTime(2026, 6, 17, 9)), isFalse);
    expect(reservation.canBeEditedAt(DateTime(2026, 6, 18, 8)), isFalse);
  });

  test(
    'short notice reservations can be cancelled during grace period only',
    () {
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 9),
        endAt: DateTime(2026, 6, 18, 17),
        createdAt: DateTime(2026, 6, 18, 7, 30),
      );

      expect(
        reservation.canBeCancelledAt(DateTime(2026, 6, 18, 7, 59)),
        isTrue,
      );
      expect(
        reservation.canBeCancelledAt(DateTime(2026, 6, 18, 8, 30)),
        isTrue,
      );
      expect(
        reservation.canBeCancelledAt(DateTime(2026, 6, 18, 8, 30, 1)),
        isFalse,
      );
      expect(reservation.canBeCancelledAt(DateTime(2026, 6, 18, 9)), isFalse);
    },
  );

  test(
    'short notice reservations without creation date cannot be cancelled',
    () {
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 9),
        endAt: DateTime(2026, 6, 18, 17),
      );

      expect(reservation.canBeCancelledAt(DateTime(2026, 6, 18, 8)), isFalse);
    },
  );

  test('started reservations cannot be cancelled during grace period', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      createdAt: DateTime(2026, 6, 18, 7, 30),
      hasOpenConstat: true,
    );

    expect(reservation.canBeCancelledAt(DateTime(2026, 6, 18, 8)), isFalse);
  });

  test('advance reservations can be cancelled before the edit lock window', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      createdAt: DateTime(2026, 6, 10, 9),
    );

    expect(reservation.canBeCancelledAt(DateTime(2026, 6, 17, 8, 59)), isTrue);
    expect(reservation.canBeCancelledAt(DateTime(2026, 6, 17, 9)), isFalse);
  });

  test('departure action is shown only from one hour before start', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
    );

    expect(
      reservation.shouldShowDepartureActionAt(DateTime(2026, 6, 18, 7, 59)),
      isFalse,
    );
    expect(
      reservation.shouldShowDepartureActionAt(DateTime(2026, 6, 18, 8)),
      isTrue,
    );
  });

  test(
    'departure action stays available after expected return if not started',
    () {
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      expect(
        reservation.shouldShowDepartureActionAt(DateTime(2026, 6, 18, 8, 47)),
        isTrue,
      );
      expect(
        reservation.canOpenPickupFormAt(DateTime(2026, 6, 18, 8, 47)),
        isTrue,
      );
    },
  );

  test('departure reminder is created even after expected return', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 8, 30),
      endAt: DateTime(2026, 6, 18, 8, 40),
    );

    expect(
      reservation.shouldCreateDepartureReminderAt(DateTime(2026, 6, 18, 8, 44)),
      isFalse,
    );
    expect(
      reservation.shouldCreateDepartureReminderAt(DateTime(2026, 6, 18, 8, 45)),
      isTrue,
    );
  });

  test('admin alert for unstarted departure waits thirty minutes', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 8, 30),
      endAt: DateTime(2026, 6, 18, 17),
    );

    expect(
      reservation.shouldNotifyAdminForUnstartedDepartureAt(
        DateTime(2026, 6, 18, 8, 59),
      ),
      isFalse,
    );
    expect(
      reservation.shouldNotifyAdminForUnstartedDepartureAt(
        DateTime(2026, 6, 18, 9),
      ),
      isTrue,
    );
  });

  test('return form opens immediately after departure confirmation', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      hasOpenConstat: true,
    );

    expect(
      reservation.shouldShowReturnActionAt(DateTime(2026, 6, 18, 10)),
      isTrue,
    );
    expect(reservation.canOpenReturnFormAt(DateTime(2026, 6, 18, 10)), isTrue);
    expect(
      reservation.shouldShowReturnActionAt(DateTime(2026, 6, 18, 16)),
      isTrue,
    );
    expect(reservation.canOpenReturnFormAt(DateTime(2026, 6, 18, 16)), isTrue);
    expect(
      reservation.shouldCreateReturnReminderAt(DateTime(2026, 6, 18, 17, 29)),
      isFalse,
    );
    expect(
      reservation.shouldCreateReturnReminderAt(DateTime(2026, 6, 18, 17, 30)),
      isTrue,
    );
  });

  test('return action is never shown before departure confirmation', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
    );

    expect(
      reservation.shouldShowReturnActionAt(DateTime(2026, 6, 18, 16)),
      isFalse,
    );
    expect(reservation.canOpenReturnFormAt(DateTime(2026, 6, 18, 16)), isFalse);
  });

  test('return action is hidden when a closed constat already exists', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      hasOpenConstat: true,
      hasClosedConstat: true,
    );

    expect(
      reservation.shouldShowReturnActionAt(DateTime(2026, 6, 18, 16)),
      isFalse,
    );
    expect(reservation.canOpenReturnFormAt(DateTime(2026, 6, 18, 16)), isFalse);
  });

  test('open constats stay out of history while status is not completed', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      hasOpenConstat: true,
    );

    expect(reservation.isInHistory, isFalse);
    expect(
      reservation.shouldCreateReturnReminderAt(DateTime(2026, 6, 18, 17, 30)),
      isTrue,
    );
  });

  test('completed reservations enter history after return confirmation', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      status: ReservationStatus.completed,
    );

    expect(reservation.isInHistory, isTrue);
    expect(
      reservation.shouldCreateReturnReminderAt(DateTime(2026, 6, 18, 17, 30)),
      isFalse,
    );
  });

  test(
    'terminated reservations enter history even with an upcoming status',
    () {
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 9),
        endAt: DateTime(2026, 6, 18, 17),
        isTerminated: true,
      );

      expect(reservation.isInHistory, isTrue);
      expect(
        reservation.shouldShowDepartureActionAt(DateTime(2026, 6, 18, 10)),
        isFalse,
      );
      expect(
        reservation.shouldShowReturnActionAt(DateTime(2026, 6, 18, 16)),
        isFalse,
      );
    },
  );

  test('completed status wins over stale open constat state', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      hasOpenConstat: true,
      status: ReservationStatus.completed,
    );

    expect(reservation.isInHistory, isTrue);
    expect(
      reservation.shouldShowDepartureActionAt(DateTime(2026, 6, 18, 10)),
      isFalse,
    );
    expect(
      reservation.shouldShowReturnActionAt(DateTime(2026, 6, 18, 16)),
      isFalse,
    );
  });

  test('terminated reservations move reservations to history', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      hasClosedConstat: true,
    );

    expect(reservation.isInHistory, isTrue);
  });

  test('closed constats prevent starting the same reservation again', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      hasClosedConstat: true,
      createdAt: DateTime(2026, 6, 10, 9),
    );

    expect(reservation.canBeCancelledAt(DateTime(2026, 6, 17, 8, 59)), isFalse);
    expect(
      reservation.shouldShowDepartureActionAt(DateTime(2026, 6, 18, 10)),
      isFalse,
    );
    expect(
      reservation.shouldCreateDepartureReminderAt(DateTime(2026, 6, 18, 9, 30)),
      isFalse,
    );
    expect(
      reservation.shouldNotifyAdminForUnstartedDepartureAt(
        DateTime(2026, 6, 18, 9, 30),
      ),
      isFalse,
    );
    expect(
      reservation.shouldCreateReturnReminderAt(DateTime(2026, 6, 18, 17, 30)),
      isFalse,
    );
  });

  test(
    'effective end uses the actual return when vehicle is returned early',
    () {
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 5, 10),
        endAt: DateTime(2026, 6, 7, 10),
        isTerminated: true,
        returnedAt: DateTime(2026, 6, 5, 10, 30),
      );

      expect(reservation.effectiveEndAt, DateTime(2026, 6, 5, 10, 30));
    },
  );
}

FleetReservation _reservation({
  required DateTime startAt,
  required DateTime endAt,
  bool hasOpenConstat = false,
  bool hasClosedConstat = false,
  ReservationStatus status = ReservationStatus.upcoming,
  DateTime? createdAt,
  bool isTerminated = false,
  DateTime? returnedAt,
}) {
  return FleetReservation(
    id: '1',
    vehicle: _vehicle,
    location: 'Site',
    startAt: startAt,
    endAt: endAt,
    startLabel: 'Départ',
    endLabel: 'Retour',
    status: status,
    expectedStartMileage: 100,
    createdAt: createdAt,
    hasOpenConstat: hasOpenConstat,
    hasClosedConstat: hasClosedConstat,
    isTerminated: isTerminated,
    returnedAt: returnedAt,
  );
}

final _vehicle = Vehicle(
  id: '1',
  internalNumber: 'V-001',
  name: 'Renault Clio',
  brand: 'Renault',
  model: 'Clio',
  plateNumber: 'AA-123-AA',
  category: 'Flotte',
  status: VehicleStatus.available,
  subtitle: 'Libre',
  imageUrl: '',
  location: 'Site',
  site: 'Site',
  parkingDescription: 'Parking',
  seats: '5',
  transmission: 'Manuelle',
  energyType: VehicleEnergyType.thermal,
  energyInfo: 'Thermique',
  currentMileage: 100,
  fuelLevelLabel: '50%',
  priorityRank: 1,
  nextAvailableAt: DateTime(2026, 6, 18),
  availabilityByDay: const {},
);
