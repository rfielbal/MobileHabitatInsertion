import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_habitat_insertion/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example.test/HabitatInsertion/api\n',
    );
  });

  testWidgets('app starts on the mobile login screen', (tester) async {
    await tester.pumpWidget(const WheelloApp(forceLogin: true));
    await tester.pumpAndSettle();

    expect(find.text('Wheello'), findsOneWidget);
    expect(find.text('E-mail ou identifiant'), findsOneWidget);
    expect(find.text('Mot de passe'), findsNothing);
  });
}
