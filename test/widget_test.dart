import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/main.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/screens/fleet/vehicles_screen.dart';
import 'package:mobile_habitat_insertion/theme/app_colors.dart';
import 'package:mobile_habitat_insertion/theme/app_theme.dart';
import 'package:mobile_habitat_insertion/widgets/availability_calendar.dart';
import 'package:mobile_habitat_insertion/widgets/reservation_band_calendar.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Wheello login screen is displayed', (tester) async {
    await tester.pumpWidget(const WheelloApp(forceLogin: true));

    expect(find.text('Wheello'), findsOneWidget);
    expect(find.text('E-mail ou identifiant'), findsOneWidget);
    expect(find.text('Mot de passe'), findsNothing);
  });

  testWidgets('Vehicles screen has no overflow on narrow Android viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const VehiclesScreen()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Availability calendar renders statuses and handles day tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selectedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: AvailabilityCalendar(
                month: DateTime(2026, 6),
                availabilityByDay: const {
                  18: AvailabilityStatus.free,
                  19: AvailabilityStatus.partial,
                  20: AvailabilityStatus.maintenance,
                },
                userUnavailableDays: const {21},
                rangeStartDate: DateTime(2026, 6, 18),
                rangeEndDate: DateTime(2026, 6, 21),
                onDaySelected: (day) => selectedDay = day,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Juin 2026'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('20'));
    await tester.pump();

    expect(selectedDay, 20);
  });

  testWidgets('Availability calendar disables days before minimum date', (
    tester,
  ) async {
    int? selectedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AvailabilityCalendar(
              month: DateTime(2026, 6),
              availabilityByDay: const {},
              minimumSelectableDate: DateTime(2026, 6, 23),
              onDaySelected: (day) => selectedDay = day,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('22'));
    await tester.pump();
    expect(selectedDay, isNull);

    await tester.tap(find.text('23'));
    await tester.pump();
    expect(selectedDay, 23);
  });

  testWidgets('Reservation band calendar overlays touching reservations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReservationBandCalendar(
              month: DateTime(2026, 6),
              reservations: [
                _calendarReservation(
                  id: 'return',
                  startAt: DateTime(2026, 6, 4, 18),
                  endAt: DateTime(2026, 6, 6, 10),
                ),
                _calendarReservation(
                  id: 'departure',
                  startAt: DateTime(2026, 6, 6, 16),
                  endAt: DateTime(2026, 6, 10, 10),
                ),
              ],
              canGoToPreviousMonth: false,
              onPreviousMonth: () {},
              onNextMonth: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Juin 2026'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reservation band calendar greys past days', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReservationBandCalendar(
              month: DateTime(2026, 6),
              now: DateTime(2026, 6, 9, 12),
              reservations: const [],
              canGoToPreviousMonth: false,
              onPreviousMonth: () {},
              onNextMonth: () {},
            ),
          ),
        ),
      ),
    );

    final pastDay = tester.widget<Text>(find.text('8'));
    final currentDay = tester.widget<Text>(find.text('9'));

    expect(pastDay.style?.color, AppColors.outline);
    expect(currentDay.style?.color, AppColors.onSurface);
  });
}

FleetReservation _calendarReservation({
  required String id,
  required DateTime startAt,
  required DateTime endAt,
}) {
  return FleetReservation(
    id: id,
    vehicle: _calendarVehicle,
    location: 'Site',
    startAt: startAt,
    endAt: endAt,
    startLabel: 'Départ',
    endLabel: 'Retour',
    status: ReservationStatus.upcoming,
    expectedStartMileage: 100,
  );
}

final _calendarVehicle = Vehicle(
  id: '1',
  internalNumber: 'V-001',
  name: 'Citroen C3',
  brand: 'Citroen',
  model: 'C3',
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
  nextAvailableAt: DateTime(2026, 6, 1),
  availabilityByDay: const {},
);
