import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/utils/reservation_calendar_days.dart';

void main() {
  group('occupiedReservationDaysForMonth', () {
    test('marks every occupied day across the selected month', () {
      final days = occupiedReservationDaysForMonth(
        startAt: DateTime(2026, 6, 29, 8, 30),
        endAt: DateTime(2026, 7, 2, 18),
        month: DateTime(2026, 6),
      );

      expect(days, {29, 30});
    });

    test('marks the next month portion of a multi-month reservation', () {
      final days = occupiedReservationDaysForMonth(
        startAt: DateTime(2026, 6, 29, 8, 30),
        endAt: DateTime(2026, 7, 2, 18),
        month: DateTime(2026, 7),
      );

      expect(days, {1, 2});
    });

    test('does not block the return day when reservation ends at midnight', () {
      final days = occupiedReservationDaysForMonth(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 19),
        month: DateTime(2026, 6),
      );

      expect(days, {18});
    });

    test('returns no occupied days for invalid or zero-length ranges', () {
      expect(
        occupiedReservationDaysForMonth(
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 18, 8, 30),
          month: DateTime(2026, 6),
        ),
        isEmpty,
      );
    });
  });

  group('userUnavailableReservationDaysForMonth', () {
    test('blocks active user reservations even when vehicle is different', () {
      final reservations = [
        _reservation(
          id: 'a',
          vehicleId: '1',
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 18, 17),
        ),
        _reservation(
          id: 'b',
          vehicleId: '2',
          startAt: DateTime(2026, 6, 20, 9),
          endAt: DateTime(2026, 6, 21, 12),
        ),
      ];

      expect(
        userUnavailableReservationDaysForMonth(
          reservations: reservations,
          month: DateTime(2026, 6),
        ),
        {18, 20, 21},
      );
    });

    test('ignores history, closed constats and the edited reservation', () {
      final reservations = [
        _reservation(
          id: 'edited',
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 18, 17),
        ),
        _reservation(
          id: 'history',
          startAt: DateTime(2026, 6, 19, 8, 30),
          endAt: DateTime(2026, 6, 19, 17),
          status: ReservationStatus.completed,
        ),
        _reservation(
          id: 'closed',
          startAt: DateTime(2026, 6, 20, 8, 30),
          endAt: DateTime(2026, 6, 20, 17),
          hasClosedConstat: true,
        ),
        _reservation(
          id: 'active',
          startAt: DateTime(2026, 6, 21, 8, 30),
          endAt: DateTime(2026, 6, 21, 17),
        ),
      ];

      expect(
        userUnavailableReservationDaysForMonth(
          reservations: reservations,
          month: DateTime(2026, 6),
          excludedReservationId: 'edited',
        ),
        {21},
      );
    });

    test('does not block the day after a reservation ending at midnight', () {
      final reservations = [
        _reservation(
          id: 'night',
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 19),
        ),
      ];

      expect(
        userUnavailableReservationDaysForMonth(
          reservations: reservations,
          month: DateTime(2026, 6),
        ),
        {18},
      );
    });
  });

  group('reservationPeriodContainsUnavailableDayForMonth', () {
    test('detects reserved, maintenance and user-unavailable days', () {
      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 21, 18),
          month: DateTime(2026, 6),
          availabilityByDay: {
            19: AvailabilityStatus.reserved,
            20: AvailabilityStatus.maintenance,
          },
        ),
        isTrue,
      );

      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 19, 18),
          month: DateTime(2026, 6),
          availabilityByDay: const {},
          userUnavailableDays: {18},
        ),
        isTrue,
      );
    });

    test('allows free periods and ignored original reservation days', () {
      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 19, 18),
          month: DateTime(2026, 6),
          availabilityByDay: {18: AvailabilityStatus.reserved},
          userUnavailableDays: {19},
          ignoredDays: {18, 19},
        ),
        isFalse,
      );

      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 19, 18),
          month: DateTime(2026, 6),
          availabilityByDay: const {},
        ),
        isFalse,
      );
    });

    test('does not treat an exact midnight end as occupying that day', () {
      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 18, 8, 30),
          endAt: DateTime(2026, 6, 19),
          month: DateTime(2026, 6),
          availabilityByDay: {19: AvailabilityStatus.reserved},
        ),
        isFalse,
      );
    });

    test('detects cross-month conflicts in the active month only', () {
      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 30, 8, 30),
          endAt: DateTime(2026, 7, 2, 18),
          month: DateTime(2026, 7),
          availabilityByDay: {1: AvailabilityStatus.free},
          userUnavailableDays: {2},
        ),
        isTrue,
      );
    });

    test('allows partial days but blocks fully reserved days', () {
      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 4, 11),
          endAt: DateTime(2026, 6, 4, 18),
          month: DateTime(2026, 6),
          availabilityByDay: {4: AvailabilityStatus.partial},
        ),
        isFalse,
      );

      expect(
        reservationPeriodContainsUnavailableDayForMonth(
          startAt: DateTime(2026, 6, 4, 11),
          endAt: DateTime(2026, 6, 4, 18),
          month: DateTime(2026, 6),
          availabilityByDay: {4: AvailabilityStatus.reserved},
        ),
        isTrue,
      );
    });
  });

  group('reservationPeriodsOverlap', () {
    test('allows a same-day booking after the previous return time', () {
      expect(
        reservationPeriodsOverlap(
          firstStartAt: DateTime(2026, 6, 4, 11),
          firstEndAt: DateTime(2026, 6, 4, 18),
          secondStartAt: DateTime(2026, 6, 4, 8),
          secondEndAt: DateTime(2026, 6, 4, 9),
        ),
        isFalse,
      );
    });

    test('detects same-day overlapping booking periods', () {
      expect(
        reservationPeriodsOverlap(
          firstStartAt: DateTime(2026, 6, 4, 8, 30),
          firstEndAt: DateTime(2026, 6, 4, 12),
          secondStartAt: DateTime(2026, 6, 4, 9),
          secondEndAt: DateTime(2026, 6, 4, 11),
        ),
        isTrue,
      );
    });

    test('enforces the one hour vehicle turnaround when requested', () {
      expect(
        reservationPeriodsOverlap(
          firstStartAt: DateTime(2026, 6, 4, 8, 59),
          firstEndAt: DateTime(2026, 6, 4, 18),
          secondStartAt: DateTime(2026, 6, 4, 7),
          secondEndAt: DateTime(2026, 6, 4, 8),
          minimumTurnaround: reservationTurnaroundDuration,
        ),
        isTrue,
      );

      expect(
        reservationPeriodsOverlap(
          firstStartAt: DateTime(2026, 6, 4, 9),
          firstEndAt: DateTime(2026, 6, 4, 18),
          secondStartAt: DateTime(2026, 6, 4, 7),
          secondEndAt: DateTime(2026, 6, 4, 8),
          minimumTurnaround: reservationTurnaroundDuration,
        ),
        isFalse,
      );

      expect(
        reservationPeriodsOverlap(
          firstStartAt: DateTime(2026, 6, 6, 8),
          firstEndAt: DateTime(2026, 6, 8, 12, 1),
          secondStartAt: DateTime(2026, 6, 8, 13),
          secondEndAt: DateTime(2026, 6, 8, 18),
          minimumTurnaround: reservationTurnaroundDuration,
        ),
        isTrue,
      );

      expect(
        reservationPeriodsOverlap(
          firstStartAt: DateTime(2026, 6, 6, 8),
          firstEndAt: DateTime(2026, 6, 8, 12),
          secondStartAt: DateTime(2026, 6, 8, 13),
          secondEndAt: DateTime(2026, 6, 8, 18),
          minimumTurnaround: reservationTurnaroundDuration,
        ),
        isFalse,
      );
    });
  });

  group('userHasOverlappingReservation', () {
    test('does not block a user for the full day after a morning return', () {
      final reservations = [
        _reservation(
          id: 'morning',
          startAt: DateTime(2026, 6, 4, 8),
          endAt: DateTime(2026, 6, 4, 9),
        ),
      ];

      expect(
        userHasOverlappingReservation(
          reservations: reservations,
          startAt: DateTime(2026, 6, 4, 11),
          endAt: DateTime(2026, 6, 4, 18),
        ),
        isFalse,
      );
    });

    test('ignores closed and edited reservations for overlap checks', () {
      final reservations = [
        _reservation(
          id: 'closed',
          startAt: DateTime(2026, 6, 4, 8),
          endAt: DateTime(2026, 6, 4, 18),
          hasClosedConstat: true,
        ),
        _reservation(
          id: 'edited',
          startAt: DateTime(2026, 6, 5, 8),
          endAt: DateTime(2026, 6, 5, 18),
        ),
      ];

      expect(
        userHasOverlappingReservation(
          reservations: reservations,
          startAt: DateTime(2026, 6, 4, 11),
          endAt: DateTime(2026, 6, 5, 12),
          excludedReservationId: 'edited',
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
  String vehicleId = '1',
  ReservationStatus status = ReservationStatus.upcoming,
  bool hasClosedConstat = false,
}) {
  return FleetReservation(
    id: id,
    vehicle: _vehicle(vehicleId),
    location: 'Site',
    startAt: startAt,
    endAt: endAt,
    startLabel: 'Départ',
    endLabel: 'Retour',
    status: status,
    expectedStartMileage: 100,
    hasClosedConstat: hasClosedConstat,
  );
}

Vehicle _vehicle(String id) {
  return Vehicle(
    id: id,
    internalNumber: 'V-$id',
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
}
