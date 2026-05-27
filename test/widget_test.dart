import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/main.dart';

void main() {
  testWidgets('FlotteManager login screen is displayed', (tester) async {
    await tester.pumpWidget(const FleetManagerApp());

    expect(find.text('FlotteManager'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });
}
