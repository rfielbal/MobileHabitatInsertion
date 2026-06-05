import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/utils/reservation_time_constraints.dart';

void main() {
  group('suggestedReservationStartAt', () {
    test('uses midnight for a future day without reservations', () {
      expect(
        suggestedReservationStartAt(
          date: DateTime(2026, 6, 10),
          suggestionsByDay: const {},
          now: DateTime(2026, 6, 5, 14, 20),
        ),
        DateTime(2026, 6, 10),
      );
    });

    test('uses current time plus one hour for today without reservations', () {
      expect(
        suggestedReservationStartAt(
          date: DateTime(2026, 6, 5),
          suggestionsByDay: const {},
          now: DateTime(2026, 6, 5, 14, 20),
        ),
        DateTime(2026, 6, 5, 15, 20),
      );
    });

    test('uses the previous vehicle return plus one hour on partial days', () {
      expect(
        suggestedReservationStartAt(
          date: DateTime(2026, 6, 17),
          suggestionsByDay: {
            17: VehicleAvailabilitySuggestion(
              earliestStartAt: DateTime(2026, 6, 17, 18),
            ),
          },
          now: DateTime(2026, 6, 5, 14),
        ),
        DateTime(2026, 6, 17, 18),
      );
    });

    test('does not suggest an hour before now plus one hour for today', () {
      expect(
        suggestedReservationStartAt(
          date: DateTime(2026, 6, 5),
          suggestionsByDay: {
            5: VehicleAvailabilitySuggestion(
              earliestStartAt: DateTime(2026, 6, 5, 14, 30),
            ),
          },
          now: DateTime(2026, 6, 5, 14),
        ),
        DateTime(2026, 6, 5, 15),
      );
    });
  });

  group('suggestedReservationEndAt', () {
    test('uses midnight for a return day without reservations', () {
      expect(
        suggestedReservationEndAt(
          date: DateTime(2026, 6, 15),
          suggestionsByDay: const {},
        ),
        DateTime(2026, 6, 15),
      );
    });

    test('uses the departure time plus one hour for a same-day return', () {
      expect(
        suggestedReservationEndAt(
          date: DateTime(2026, 6, 15),
          suggestionsByDay: const {},
          startAt: DateTime(2026, 6, 15, 9, 30),
        ),
        DateTime(2026, 6, 15, 10, 30),
      );
    });

    test('keeps a stricter latest return on same-day reservations', () {
      expect(
        suggestedReservationEndAt(
          date: DateTime(2026, 6, 15),
          suggestionsByDay: {
            15: VehicleAvailabilitySuggestion(
              latestEndAt: DateTime(2026, 6, 15, 10),
            ),
          },
          startAt: DateTime(2026, 6, 15, 9, 30),
        ),
        DateTime(2026, 6, 15, 10),
      );
    });

    test('uses the next vehicle departure minus one hour', () {
      expect(
        suggestedReservationEndAt(
          date: DateTime(2026, 6, 15),
          suggestionsByDay: {
            15: VehicleAvailabilitySuggestion(
              latestEndAt: DateTime(2026, 6, 15, 17),
            ),
          },
        ),
        DateTime(2026, 6, 15, 17),
      );
    });

    test('uses the next user departure minus one hour', () {
      expect(
        suggestedReservationEndAt(
          date: DateTime(2026, 6, 4),
          suggestionsByDay: const {},
          userReservations: [
            _reservation(
              id: 'next-user-trip',
              startAt: DateTime(2026, 6, 4, 13),
              endAt: DateTime(2026, 6, 4, 18),
            ),
          ],
        ),
        DateTime(2026, 6, 4, 12),
      );
    });

    test(
      'keeps the strictest latest return between vehicle and user trips',
      () {
        expect(
          suggestedReservationEndAt(
            date: DateTime(2026, 6, 4),
            suggestionsByDay: {
              4: VehicleAvailabilitySuggestion(
                latestEndAt: DateTime(2026, 6, 4, 17),
              ),
            },
            userReservations: [
              _reservation(
                id: 'next-user-trip',
                startAt: DateTime(2026, 6, 4, 13),
                endAt: DateTime(2026, 6, 4, 18),
              ),
            ],
          ),
          DateTime(2026, 6, 4, 12),
        );
      },
    );

    test('ignores completed, closed and edited user reservations', () {
      expect(
        suggestedReservationEndAt(
          date: DateTime(2026, 6, 4),
          suggestionsByDay: const {},
          userReservations: [
            _reservation(
              id: 'completed',
              startAt: DateTime(2026, 6, 4, 10),
              endAt: DateTime(2026, 6, 4, 12),
              status: ReservationStatus.completed,
            ),
            _reservation(
              id: 'closed',
              startAt: DateTime(2026, 6, 4, 11),
              endAt: DateTime(2026, 6, 4, 13),
              hasClosedConstat: true,
            ),
            _reservation(
              id: 'edited',
              startAt: DateTime(2026, 6, 4, 13),
              endAt: DateTime(2026, 6, 4, 18),
            ),
          ],
          excludedReservationId: 'edited',
        ),
        DateTime(2026, 6, 4),
      );
    });
  });

  group('reservation time constraints', () {
    test('rejects a departure less than one hour after a vehicle return', () {
      final suggestionsByDay = {
        4: VehicleAvailabilitySuggestion(
          earliestStartAt: DateTime(2026, 6, 4, 18),
        ),
      };

      expect(
        reservationStartViolatesEarliestStart(
          startAt: DateTime(2026, 6, 4, 17, 30),
          suggestionsByDay: suggestionsByDay,
        ),
        isTrue,
      );
      expect(
        reservationStartViolatesEarliestStart(
          startAt: DateTime(2026, 6, 4, 18),
          suggestionsByDay: suggestionsByDay,
        ),
        isFalse,
      );
    });

    test('rejects a return less than one hour before the next departure', () {
      final suggestionsByDay = {
        4: VehicleAvailabilitySuggestion(latestEndAt: DateTime(2026, 6, 4, 12)),
      };

      expect(
        reservationEndViolatesLatestEnd(
          endAt: DateTime(2026, 6, 4, 12, 30),
          suggestionsByDay: suggestionsByDay,
        ),
        isTrue,
      );
      expect(
        reservationEndViolatesLatestEnd(
          endAt: DateTime(2026, 6, 4, 12),
          suggestionsByDay: suggestionsByDay,
        ),
        isFalse,
      );
    });
  });
}

FleetReservation _reservation({
  required String id,
  required DateTime startAt,
  required DateTime endAt,
  ReservationStatus status = ReservationStatus.upcoming,
  bool hasClosedConstat = false,
}) {
  return FleetReservation(
    id: id,
    vehicle: _vehicle,
    location: 'Site',
    startAt: startAt,
    endAt: endAt,
    startLabel: 'Depart',
    endLabel: 'Retour',
    status: status,
    expectedStartMileage: 100,
    hasClosedConstat: hasClosedConstat,
  );
}

final _vehicle = Vehicle(
  id: '1',
  internalNumber: 'V-1',
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
