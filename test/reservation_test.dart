import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';

void main() {
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

  test('return form opens only from one hour before expected return', () {
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 9),
      endAt: DateTime(2026, 6, 18, 17),
      hasOpenConstat: true,
    );

    expect(
      reservation.shouldShowReturnActionAt(DateTime(2026, 6, 18, 10)),
      isTrue,
    );
    expect(
      reservation.canOpenReturnFormAt(DateTime(2026, 6, 18, 15, 59)),
      isFalse,
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
}

FleetReservation _reservation({
  required DateTime startAt,
  required DateTime endAt,
  bool hasOpenConstat = false,
}) {
  return FleetReservation(
    id: '1',
    vehicle: _vehicle,
    location: 'Site',
    startAt: startAt,
    endAt: endAt,
    startLabel: 'Départ',
    endLabel: 'Retour',
    status: ReservationStatus.upcoming,
    expectedStartMileage: 100,
    hasOpenConstat: hasOpenConstat,
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
