import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
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

  test('reservation mapper detects open constats', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      'constats': [
        {'estOuvert': true},
      ],
    });

    expect(reservation.hasOpenConstat, isTrue);
  });

  test('reservation mapper detects open constats from status', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      'constats': [
        {'statut': 'en_cours', 'datePrise': '2026-06-18T09:00:00Z'},
      ],
    });

    expect(reservation.hasOpenConstat, isTrue);
  });

  test('reservation mapper detects closed constats', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      'constats': [
        {'estOuvert': false, 'dateRendu': '2026-06-18T16:59:59Z'},
      ],
    });

    expect(reservation.hasClosedConstat, isTrue);
    expect(reservation.isInHistory, isFalse);
  });

  test('reservation mapper detects final mileage as closed constat', () {
    final reservation = FleetApiMappers.reservationFromJson({
      'id': 1,
      'dateDebut': '2026-06-18T09:00:00Z',
      'dateFin': '2026-06-18T17:00:00Z',
      'vehicule': {'id': 10, 'marque': 'Renault', 'modele': 'Clio'},
      'constats': [
        {'kmFin': 120},
      ],
    });

    expect(reservation.hasClosedConstat, isTrue);
    expect(reservation.isInHistory, isFalse);
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
