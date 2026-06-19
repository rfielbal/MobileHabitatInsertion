import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/utils/vehicle_sort.dart';

void main() {
  test(
    'sortVehiclesByRecommendation prioritizes closest site then mileage',
    () {
      final vehicles = [
        _vehicle(id: 'far-low-mileage', site: 'Site B', currentMileage: 2000),
        _vehicle(id: 'near-high-mileage', site: 'Site A', currentMileage: 9000),
        _vehicle(id: 'near-low-mileage', site: 'Site A', currentMileage: 1000),
      ];

      sortVehiclesByRecommendation(
        vehicles,
        sitePriority: ['Site A', 'Site B'],
      );

      expect(vehicles.map((vehicle) => vehicle.id), [
        'near-low-mileage',
        'near-high-mileage',
        'far-low-mileage',
      ]);
    },
  );

  test(
    'sortVehiclesByRecommendation falls back to mileage without site order',
    () {
      final vehicles = [
        _vehicle(id: 'high-mileage', site: 'Site B', currentMileage: 9000),
        _vehicle(id: 'low-mileage', site: 'Site A', currentMileage: 1000),
      ];

      sortVehiclesByRecommendation(vehicles);

      expect(vehicles.map((vehicle) => vehicle.id), [
        'low-mileage',
        'high-mileage',
      ]);
    },
  );
}

Vehicle _vehicle({
  required String id,
  required String site,
  required int currentMileage,
}) {
  return Vehicle(
    id: id,
    internalNumber: id,
    name: id,
    brand: 'Renault',
    model: 'Clio',
    plateNumber: 'AA-123-AA',
    category: 'Flotte',
    status: VehicleStatus.available,
    subtitle: VehicleStatus.available.label,
    imageUrl: 'https://example.test/car.png',
    location: site,
    site: site,
    parkingDescription: 'Parking',
    seats: '5',
    transmission: 'Manuelle',
    energyType: VehicleEnergyType.thermal,
    energyInfo: VehicleEnergyType.thermal.label,
    currentMileage: currentMileage,
    fuelLevelLabel: 'Non renseigné',
    priorityRank: VehicleStatus.available.sortRank,
    nextAvailableAt: DateTime(2026, 6, 19),
    availabilityByDay: const {},
  );
}
