import '../models/reservation.dart';
import '../models/vehicle.dart';

class MockFleetData {
  const MockFleetData._();

  static const _peugeotImage = '';
  static const _kangooImage = '';
  static const _teslaImage = '';
  static const _golfImage = '';
  static const _detailPeugeotImage = '';

  static final vehicles = <Vehicle>[
    Vehicle(
      id: 'peugeot-3008',
      internalNumber: 'V-001',
      name: 'Peugeot 3008',
      brand: 'Peugeot',
      model: '3008 Hybrid',
      plateNumber: 'AB-123-CD',
      category: 'Berline',
      status: VehicleStatus.inUse,
      subtitle: 'J. Dupont • Retour 17h',
      imageUrl: _peugeotImage,
      location: 'Site Béthune',
      site: 'Béthune',
      parkingDescription: 'Parking personnel, entrée principale',
      seats: '5 Places',
      transmission: 'Automatique',
      energyType: VehicleEnergyType.hybrid,
      energyInfo: '50km Élec.',
      currentMileage: 45210,
      fuelLevelLabel: '65%',
      priorityRank: 2,
      nextAvailableAt: DateTime(2026, 5, 27, 17),
      availabilityByDay: _availability,
      knownIssues: _peugeotIssues,
    ),
    Vehicle(
      id: 'renault-kangoo',
      internalNumber: 'V-002',
      name: 'Renault Kangoo',
      brand: 'Renault',
      model: 'Kangoo Z.E.',
      plateNumber: 'EF-456-GH',
      category: 'Utilitaires',
      status: VehicleStatus.available,
      subtitle: 'Libre',
      imageUrl: _kangooImage,
      location: 'Site Bruay',
      site: 'Bruay',
      parkingDescription: 'Zone utilitaires, portail nord',
      seats: '2 Places',
      transmission: 'Manuelle',
      energyType: VehicleEnergyType.electric,
      energyInfo: 'Électrique',
      currentMileage: 31880,
      fuelLevelLabel: 'Batterie 82%',
      priorityRank: 1,
      nextAvailableAt: DateTime(2026, 5, 28, 12),
      availabilityByDay: _availability,
      knownIssues: _kangooIssues,
    ),
    Vehicle(
      id: 'tesla-model-3',
      internalNumber: 'V-003',
      name: 'Tesla Model 3',
      brand: 'Tesla',
      model: 'Model 3',
      plateNumber: 'IJ-789-KL',
      category: 'Berline',
      status: VehicleStatus.available,
      subtitle: '100% • Prêt au départ',
      imageUrl: _teslaImage,
      location: 'Site Béthune',
      site: 'Béthune',
      parkingDescription: 'Borne électrique côté accueil',
      seats: '5 Places',
      transmission: 'Automatique',
      energyType: VehicleEnergyType.electric,
      energyInfo: '100% Élec.',
      currentMileage: 12420,
      fuelLevelLabel: 'Batterie 100%',
      priorityRank: 1,
      nextAvailableAt: DateTime(2026, 5, 27, 8),
      availabilityByDay: _availability,
    ),
    Vehicle(
      id: 'vw-golf',
      internalNumber: 'V-004',
      name: 'VW Golf',
      brand: 'Volkswagen',
      model: 'Golf',
      plateNumber: 'MN-012-OP',
      category: 'Berline',
      status: VehicleStatus.maintenance,
      subtitle: 'Garage central • Prévu 14/10',
      imageUrl: _golfImage,
      location: 'Garage central',
      site: 'Atelier',
      parkingDescription: 'Immobilisé au garage central',
      seats: '5 Places',
      transmission: 'Manuelle',
      energyType: VehicleEnergyType.thermal,
      energyInfo: 'Diesel',
      currentMileage: 78045,
      fuelLevelLabel: '40%',
      priorityRank: 9,
      nextAvailableAt: DateTime(2026, 6, 14, 8),
      availabilityByDay: _availability,
      knownIssues: _golfIssues,
    ),
  ];

  static Vehicle get detailVehicle {
    final vehicle = vehicles.first;
    return Vehicle(
      id: vehicle.id,
      internalNumber: vehicle.internalNumber,
      name: 'Peugeot 3008 Hybrid',
      brand: vehicle.brand,
      model: vehicle.model,
      plateNumber: vehicle.plateNumber,
      category: vehicle.category,
      status: vehicle.status,
      subtitle: vehicle.subtitle,
      imageUrl: _detailPeugeotImage,
      location: vehicle.location,
      site: vehicle.site,
      parkingDescription: vehicle.parkingDescription,
      seats: vehicle.seats,
      transmission: vehicle.transmission,
      energyType: vehicle.energyType,
      energyInfo: vehicle.energyInfo,
      currentMileage: vehicle.currentMileage,
      fuelLevelLabel: vehicle.fuelLevelLabel,
      priorityRank: vehicle.priorityRank,
      nextAvailableAt: vehicle.nextAvailableAt,
      availabilityByDay: vehicle.availabilityByDay,
      knownIssues: vehicle.knownIssues,
    );
  }

  static List<Vehicle> get sortedVehicles {
    final sorted = [...vehicles];
    sorted.sort((a, b) => a.status.sortRank.compareTo(b.status.sortRank));
    return sorted;
  }

  static List<FleetReservation> get reservations {
    return [
      FleetReservation(
        id: 'res-001',
        vehicle: detailVehicle,
        location: 'Site Béthune',
        startAt: DateTime(2026, 11, 14, 8),
        endAt: DateTime(2026, 11, 16, 18),
        startLabel: 'Mar. 14 Nov, 08:00',
        endLabel: 'Jeu. 16 Nov, 18:00',
        status: ReservationStatus.pickupToday,
        expectedStartMileage: detailVehicle.currentMileage,
      ),
      FleetReservation(
        id: 'res-002',
        vehicle: vehicles[1],
        location: 'Site Bruay',
        startAt: DateTime(2026, 11, 20, 9),
        endAt: DateTime(2026, 11, 20, 17),
        startLabel: 'Lun. 20 Nov, 09:00',
        endLabel: 'Lun. 20 Nov, 17:00',
        status: ReservationStatus.upcoming,
        expectedStartMileage: vehicles[1].currentMileage,
      ),
      FleetReservation(
        id: 'res-003',
        vehicle: Vehicle(
          id: 'peugeot-e208',
          internalNumber: 'V-005',
          name: 'Peugeot e-208',
          brand: 'Peugeot',
          model: 'e-208',
          plateNumber: 'AB-123-CD',
          category: 'Électrique',
          status: VehicleStatus.available,
          subtitle: 'Retour prévu aujourd’hui',
          imageUrl: _teslaImage,
          location: 'Site Béthune',
          site: 'Béthune',
          parkingDescription: 'Borne électrique côté accueil',
          seats: '5 Places',
          transmission: 'Automatique',
          energyType: VehicleEnergyType.electric,
          energyInfo: 'Électrique',
          currentMileage: 22540,
          fuelLevelLabel: 'Batterie 76%',
          priorityRank: 1,
          nextAvailableAt: DateTime(2026, 5, 26, 18),
          availabilityByDay: _availability,
        ),
        location: 'Site Béthune',
        startAt: DateTime(2026, 5, 26, 8),
        endAt: DateTime(2026, 5, 26, 18),
        startLabel: 'Mar. 26 Mai, 08:00',
        endLabel: 'Mar. 26 Mai, 18:00',
        status: ReservationStatus.returnToday,
        expectedStartMileage: 22540,
      ),
      FleetReservation(
        id: 'res-004',
        vehicle: Vehicle(
          id: 'citroen-c4',
          internalNumber: 'V-006',
          name: 'Citroën C4',
          brand: 'Citroën',
          model: 'C4',
          plateNumber: 'QR-345-ST',
          category: 'Berline',
          status: VehicleStatus.available,
          subtitle: 'Trajet terminé',
          imageUrl: _golfImage,
          location: 'Site Bruay',
          site: 'Bruay',
          parkingDescription: 'Parking visiteurs, rangée centrale',
          seats: '5 Places',
          transmission: 'Automatique',
          energyType: VehicleEnergyType.thermal,
          energyInfo: 'Essence',
          currentMileage: 54320,
          fuelLevelLabel: '55%',
          priorityRank: 3,
          nextAvailableAt: DateTime(2026, 5, 27, 8),
          availabilityByDay: _availability,
        ),
        location: 'Site Bruay',
        startAt: DateTime(2026, 11, 3, 10),
        endAt: DateTime(2026, 11, 5, 14),
        startLabel: 'Ven. 03 Nov, 10:00',
        endLabel: 'Dim. 05 Nov, 14:00',
        status: ReservationStatus.completed,
        expectedStartMileage: 54320,
      ),
    ];
  }

  static const _peugeotIssues = <VehicleIssue>[
    VehicleIssue(
      title: 'Rayure aile arrière droite',
      description: 'Signalée lors du dernier retour, déjà visible côté droit.',
      reportedAtLabel: 'Signalée le 24/05/2026',
    ),
    VehicleIssue(
      title: 'Pression pneu avant à surveiller',
      description: 'Contrôle prévu par l’administrateur.',
      reportedAtLabel: 'Signalée le 26/05/2026',
      requiresAttention: true,
    ),
  ];

  static const _kangooIssues = <VehicleIssue>[
    VehicleIssue(
      title: 'Porte latérale dure',
      description: 'Ouverture possible, mais résistance constatée.',
      reportedAtLabel: 'Signalée le 25/05/2026',
    ),
  ];

  static const _golfIssues = <VehicleIssue>[
    VehicleIssue(
      title: 'Immobilisation garage',
      description: 'Entretien mécanique planifié.',
      reportedAtLabel: 'Créée par administration',
      requiresAttention: true,
    ),
  ];

  static const _availability = <int, AvailabilityStatus>{
    1: AvailabilityStatus.free,
    2: AvailabilityStatus.maintenance,
    3: AvailabilityStatus.free,
    4: AvailabilityStatus.free,
    5: AvailabilityStatus.free,
    6: AvailabilityStatus.reserved,
    7: AvailabilityStatus.reserved,
    8: AvailabilityStatus.free,
    9: AvailabilityStatus.free,
    10: AvailabilityStatus.free,
    11: AvailabilityStatus.free,
    12: AvailabilityStatus.free,
    13: AvailabilityStatus.free,
    14: AvailabilityStatus.free,
  };
}
