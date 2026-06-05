import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/utils/reservation_sync.dart';

void main() {
  test('detects active reservations deleted from the server', () {
    final deleted = _reservation(id: 'deleted');
    final kept = _reservation(id: 'kept');

    expect(
      reservationsDeletedOnServer(
        previousReservations: [deleted, kept],
        currentReservations: [kept],
      ),
      [deleted],
    );
  });

  test('ignores history and locally deleted reservations', () {
    final history = _reservation(
      id: 'history',
      status: ReservationStatus.completed,
    );
    final locallyDeleted = _reservation(id: 'local');

    expect(
      reservationsDeletedOnServer(
        previousReservations: [history, locallyDeleted],
        currentReservations: const [],
        locallyDeletedReservationIds: {'local'},
      ),
      isEmpty,
    );
  });
}

FleetReservation _reservation({
  required String id,
  ReservationStatus status = ReservationStatus.upcoming,
}) {
  return FleetReservation(
    id: id,
    vehicle: _vehicle,
    location: 'Site',
    startAt: DateTime(2026, 6, 18, 8),
    endAt: DateTime(2026, 6, 18, 17),
    startLabel: 'Jeu 18 Juin, 08:00',
    endLabel: 'Jeu 18 Juin, 17:00',
    status: status,
    expectedStartMileage: 100,
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
