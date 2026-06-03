import 'package:flutter_test/flutter_test.dart';
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
}
