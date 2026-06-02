import '../models/reservation.dart';
import '../models/vehicle.dart';

class MockFleetData {
  const MockFleetData._();

  static const _peugeotImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCxpRQJXrqL-wN7xx1p1bkH1cNCYmWMRVsYSo-19HMwsjfzN3l1ASoOmMoBGheYEb4pYB7v6bLzPE0Khw6Sp9lIWDJgzo4xhnVDxekG-s69GoIMlTA_fevIFbqutRwpZ1reWtBzup3XE_oBY6kUqZAM-rYYBBvtM3ZMPUV4YIT7GdQlfIKjITFV7ZMlsR3WeD8C1o_Z6eN6_I7MCVLDV8RFzr_Tu-e-5vSKSbvs2qCBnCc9WSrc_fQS2Ag1XbFBeLGltLq4BSpq5SA';
  static const _kangooImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBiyM9r4xFyExLo0IIX3GlqmuTF0PnSgWaJt0ryFZ-P4Ih9uQRXQErs8ma7f4humcwYlfsI0ei3ca95sXj3bCagMQuH0O3U_E6YtDx13pxuPcWelzASUonT_JzZmTpCIdlPVlToKTAmLVp0nWI1lHddO6WEt4-y0lemSZezL9IjCaGOorvjyXJ7_xh5ft8D7G0xmd8F2Dez6G8LqwfQVI9wgRwpgNuhyvnkabFWnNDrdIaLJNimSNxBjMvftejZzksHyPvBuhjbLa4';
  static const _teslaImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBrewX-yu5TLyyairug1agxvF6BiHznK3OHzTZKEtfA3ilsfDOoS1tPKcB7XtqUi50zv98u8TxR93vUkUUuMq5ge71jNgGLFfkNwG8VUryQ6RgCfS-bzX-SJAzv9tDnQonwmIa4GavZ6OqIa6m58SBTd7qVB0HrUXhAd9Y5zmc1dnibCt7Yb-6JdG2IrFn8fmp06o6jlDMfKno2qoK7NfJ3K4Hl1i_7f-hiViuHYZNI3RZND6MfRb81Px6tQwQSo6l0zVApLwT6vAo';
  static const _golfImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCjLA8C2FYSi47eHRAVFHj6-scNSpaUHxLl2C76Q2E1fwEnfeZWLMRqoGCQPb2HvEyNQKcquXmgjV93AGecMarcem-wk2CBZ4IFQ5P4fQo480PsfkrvjmHyfEPYRXeOjueDEZuV3rk3oXmkOUF0nTcPl668d_8euY4YhO5KUp_kNwt053GeIHXIaQuH9HP1nJ9DYUt4zft4sCv25uXNFzd8GHy6Sqy7PoHYl3hwyXA8V45J4S71HIVA-VkZH7GO7YPD6wZbB80lLKw';
  static const _detailPeugeotImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA6ikFZGTeJ3t9WXCFzs7QwE5RmxmwhmMrds9cT1VeSWC3GFSzCBROKnxFnyM1LRabjlF6lJtD9ucTNVdDwCdI7OETAE5V7knOoGDxZGbOPbZDWiablFhqNU86OjVAxbgut_wOybL7J2XHHLPKryrp8ZuP9riYBpAx7lxTmF9UU0QqsmPHpV288g8AiZbGp14UQh-Q61-qCzGqoSywRIadaNzwYEBHSMPlkEnCPE2Nu2IcOAFVK07ZTkxL2Wf9xpDtxQnHAj3tarac';

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
      status: VehicleStatus.partiallyAvailable,
      subtitle: 'Réservé demain 09h-12h',
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
    8: AvailabilityStatus.partial,
    9: AvailabilityStatus.free,
    10: AvailabilityStatus.free,
    11: AvailabilityStatus.free,
    12: AvailabilityStatus.free,
    13: AvailabilityStatus.free,
    14: AvailabilityStatus.free,
  };
}
