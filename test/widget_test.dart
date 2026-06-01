import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/main.dart';
import 'package:mobile_habitat_insertion/screens/fleet/vehicles_screen.dart';
import 'package:mobile_habitat_insertion/theme/app_theme.dart';
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
}
