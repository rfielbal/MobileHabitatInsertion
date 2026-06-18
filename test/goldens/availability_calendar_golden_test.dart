import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/theme/app_theme.dart';
import 'package:mobile_habitat_insertion/widgets/availability_calendar.dart';

void main() {
  testGoldens('availability calendar displays every reservation state', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: AvailabilityCalendar(
                month: DateTime(2026, 6),
                availabilityByDay: const {
                  4: AvailabilityStatus.partial,
                  5: AvailabilityStatus.reserved,
                  6: AvailabilityStatus.maintenance,
                  7: AvailabilityStatus.free,
                },
                userUnavailableDays: const {8},
                minimumSelectableDate: DateTime(2026, 6, 3),
                rangeStartDate: DateTime(2026, 6, 4),
                rangeEndDate: DateTime(2026, 6, 7),
                canGoToPreviousMonth: false,
                canGoToNextMonth: true,
                canGoToCurrentMonth: true,
                onPreviousMonth: () {},
                onNextMonth: () {},
                onCurrentMonth: () {},
                onDaySelected: (_) {},
              ),
            ),
          ),
        ),
      ),
      surfaceSize: const Size(430, 540),
    );

    await screenMatchesGolden(tester, 'availability_calendar_states');
  });
}
