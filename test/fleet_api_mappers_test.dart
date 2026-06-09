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
