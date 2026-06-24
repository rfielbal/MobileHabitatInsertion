import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/app_notification.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/services/fleet_api_mappers.dart';

void main() {
  test(
    'iso serializes local reservation times as unambiguous UTC instants',
    () {
      final selectedLocalTime = DateTime(2026, 6, 18, 12, 20);

      final serialized = FleetApiMappers.iso(selectedLocalTime);
      final parsedLocalTime = DateTime.parse(serialized).toLocal();

      expect(serialized.endsWith('Z'), isTrue);
      expect(parsedLocalTime.year, selectedLocalTime.year);
      expect(parsedLocalTime.month, selectedLocalTime.month);
      expect(parsedLocalTime.day, selectedLocalTime.day);
      expect(parsedLocalTime.hour, selectedLocalTime.hour);
      expect(parsedLocalTime.minute, selectedLocalTime.minute);
    },
  );

  test('parseApiDate keeps API instants with timezone unambiguous', () {
    final fromZulu = FleetApiMappers.parseApiDate('2026-06-18T10:20:00Z');
    final fromParisOffset = FleetApiMappers.parseApiDate(
      '2026-06-18T12:20:00+02:00',
    );

    expect(fromZulu?.toUtc(), DateTime.utc(2026, 6, 18, 10, 20));
    expect(fromParisOffset?.toUtc(), DateTime.utc(2026, 6, 18, 10, 20));
  });

  test('parseApiDate keeps timezone-less values as local wall time', () {
    final withoutTimezone = FleetApiMappers.parseApiDate('2026-06-18T12:20:00');
    final dateOnly = FleetApiMappers.parseApiDate('2026-06-18');

    expect(withoutTimezone, DateTime(2026, 6, 18, 12, 20));
    expect(dateOnly, DateTime(2026, 6, 18));
  });

  test('vehicle mapper reads current mileage from API', () {
    final vehicle = FleetApiMappers.vehicleFromJson({
      'id': 10,
      'marque': 'Citroën',
      'modele': 'C3',
      'immatriculation': 'AA-123-AA',
      'numVehicule': 114,
      'kilometrage': 45210,
    });

    expect(vehicle.internalNumber, 'V-114');
    expect(vehicle.currentMileage, 45210);
  });

  test('vehicle mapper reads new statut and image fields from API', () {
    final vehicle = FleetApiMappers.vehicleFromJson({
      'id': 10,
      'marque': 'Citroën',
      'modele': 'C3',
      'statut': 'en_utilisation',
      'cheminImage': 'https://example.test/c3.png',
    });

    expect(vehicle.status, VehicleStatus.inUse);
    expect(vehicle.imageUrl, 'https://example.test/c3.png');
  });

  test('vehicle mapper reads vehicle image gallery from API', () {
    final vehicle = FleetApiMappers.vehicleFromJson({
      'id': 10,
      'marque': 'Citroën',
      'modele': 'C3',
      'images': [
        {'url': 'https://example.test/c3-1.jpg'},
        {'url': 'https://example.test/c3-2.jpg'},
      ],
    });

    expect(vehicle.imageUrl, 'https://example.test/c3-1.jpg');
    expect(vehicle.imageUrls, [
      'https://example.test/c3-1.jpg',
      'https://example.test/c3-2.jpg',
    ]);
  });

  test('vehicle mapper reads energy type from API', () {
    final electricVehicle = FleetApiMappers.vehicleFromJson({
      'id': 10,
      'marque': 'Citroën',
      'modele': 'ë-C3',
      'energie': 'electrique',
    });
    final hybridVehicle = FleetApiMappers.vehicleFromJson({
      'id': 11,
      'marque': 'Toyota',
      'modele': 'Yaris',
      'energie': 'hybride',
    });
    final thermalVehicle = FleetApiMappers.vehicleFromJson({
      'id': 12,
      'marque': 'Renault',
      'modele': 'Clio',
      'energie': 'thermique',
    });

    expect(electricVehicle.energyType, VehicleEnergyType.electric);
    expect(hybridVehicle.energyType, VehicleEnergyType.hybrid);
    expect(thermalVehicle.energyType, VehicleEnergyType.thermal);
  });

  test('maintenance vehicle issue does not expose technical API wording', () {
    final vehicle = FleetApiMappers.vehicleFromJson({
      'id': 10,
      'marque': 'Renault',
      'modele': 'Zoé',
      'status': 'maintenance',
    });

    expect(vehicle.knownIssues, hasLength(1));
    expect(vehicle.knownIssues.single.reportedAtLabel, isNull);
  });

  test('notification mapper reads reservation target id', () {
    final payload = FleetApiMappers.notificationFromJson({
      'id': 20,
      'objet': 'Retour non effectué',
      'message': 'Le retour doit être confirmé.',
      'type': 'reservation',
      'cible_type': 'reservation',
      'cible_id': 42,
    });

    expect(payload.notification.reservationId, '42');
  });

  test('notification mapper maps mobile update action', () {
    final payload = FleetApiMappers.notificationFromJson({
      'id': 21,
      'objet': 'Mise à jour disponible',
      'message': 'Une nouvelle version de Wheello est disponible.',
      'type': 'mobile_update',
      'cible_type': 'mobile_update',
      'cible_id': 5,
    });

    expect(payload.notification.action, AppNotificationAction.openMobileUpdate);
    expect(payload.notification.reservationId, isNull);
  });

  test('reservation mapper uses vehicle mileage as expected start mileage', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {
        'id': 10,
        'marque': 'Citroën',
        'modele': 'C3',
        'kilometrage': 45210,
      },
    });

    expect(reservation.expectedStartMileage, 45210);
  });

  test(
    'reservation mapper reads planned and effective dates from new fields',
    () {
      final returnedAt = DateTime.parse('2026-06-18T14:30:00Z').toLocal();
      final reservation = FleetApiMappers.reservationFromJson({
        'id': 1,
        'dateDebutPrevue': '2026-06-18T09:00:00Z',
        'dateFinPrevue': '2026-06-18T17:00:00Z',
        'dateRetourEffectif': returnedAt.toUtc().toIso8601String(),
        'termine': true,
        'vehicule': {'id': 10, 'marque': 'Citroën', 'modele': 'C3'},
      });

      expect(
        reservation.startAt,
        DateTime.parse('2026-06-18T09:00:00Z').toLocal(),
      );
      expect(
        reservation.endAt,
        DateTime.parse('2026-06-18T17:00:00Z').toLocal(),
      );
      expect(reservation.returnedAt, returnedAt);
      expect(reservation.effectiveEndAt, returnedAt);
    },
  );

  test(
    'reservation mapper reads snake case planned and effective return dates',
    () {
      final reservation = FleetApiMappers.reservationFromJson({
        'id': 1,
        'date_debut_prevue': '2026-06-18T09:00:00Z',
        'date_fin_prevue': '2026-06-18T17:00:00Z',
        'date_retour_effectif': '2026-06-18T12:30:00Z',
        'termine': true,
        'vehicule': {'id': 10, 'marque': 'Citroën', 'modele': 'C3'},
      });

      expect(
        reservation.startAt,
        DateTime.parse('2026-06-18T09:00:00Z').toLocal(),
      );
      expect(
        reservation.endAt,
        DateTime.parse('2026-06-18T17:00:00Z').toLocal(),
      );
      expect(
        reservation.returnedAt,
        DateTime.parse('2026-06-18T12:30:00Z').toLocal(),
      );
      expect(reservation.effectiveEndAt, reservation.returnedAt);
    },
  );

  test('reservation mapper detects started reservations from demarre', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      'demarre': true,
    });

    expect(reservation.isStarted, isTrue);
    expect(reservation.hasOpenConstat, isTrue);
  });

  test('reservation mapper keeps constats from deciding started state', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      'constats': [
        {'statut': 'en_cours', 'datePrise': '2026-06-18T09:00:00Z'},
      ],
    });

    expect(reservation.isStarted, isFalse);
    expect(reservation.hasOpenConstat, isFalse);
  });

  test('reservation mapper detects returned terminated reservations', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'termine': true,
      'dateRendu': '2026-06-18T16:59:59Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
    });

    expect(reservation.isTerminated, isTrue);
    expect(reservation.hasClosedConstat, isTrue);
    expect(reservation.isInHistory, isTrue);
    expect(
      reservation.effectiveEndAt,
      DateTime.parse('2026-06-18T16:59:59Z').toLocal(),
    );
  });

  test('reservation mapper ignores final mileage without termine', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      'constats': [
        {'kmFin': 120},
      ],
    });

    expect(reservation.hasClosedConstat, isFalse);
    expect(reservation.isInHistory, isFalse);
  });

  test('reservation mapper reads constat id for started reservation', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'demarre': true,
      'constat': {'@id': '/api/metier/constats/99'},
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
    });

    expect(reservation.isStarted, isTrue);
    expect(reservation.constatId, '99');
  });

  test(
    'past expected return does not move reservation to history by itself',
    () {
      final now = DateTime.now();
      final reservation = FleetApiMappers.reservationFromJson({
        'id': 1,
        'dateDebut': now.subtract(const Duration(days: 2)).toIso8601String(),
        'dateFin': now.subtract(const Duration(days: 1)).toIso8601String(),
        'statut': 'reservee',
        'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      });

      expect(reservation.status, isNot(ReservationStatus.completed));
      expect(reservation.isInHistory, isFalse);
    },
  );

  test('statue termine moves reservation to history', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'statue': 'terminé',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
    });

    expect(reservation.status, ReservationStatus.completed);
    expect(reservation.isInHistory, isTrue);
  });

  test('termine true moves reservation to history', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'termine': true,
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
    });

    expect(reservation.isTerminated, isTrue);
    expect(reservation.hasClosedConstat, isTrue);
    expect(reservation.status, ReservationStatus.completed);
    expect(reservation.isInHistory, isTrue);
  });

  test('termine false keeps a past reservation out of history', () {
    final now = DateTime.now();
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': now.subtract(const Duration(days: 2)).toIso8601String(),
      'dateFin': now.subtract(const Duration(days: 1)).toIso8601String(),
      'termine': false,
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
    });

    expect(reservation.isTerminated, isFalse);
    expect(reservation.status, isNot(ReservationStatus.completed));
    expect(reservation.isInHistory, isFalse);
  });

  test('statut termine moves reservation to history', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'statut': 'termine',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
    });

    expect(reservation.status, ReservationStatus.completed);
    expect(reservation.isInHistory, isTrue);
  });
}
