import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile_habitat_insertion/services/api_client.dart';
import 'package:mobile_habitat_insertion/services/auth_session_service.dart';

class MockAuthSessionService extends Mock implements AuthSessionService {}

void main() {
  test(
    'ApiClient sends the stored bearer token on authenticated requests',
    () async {
      final sessionService = MockAuthSessionService();
      when(
        () => sessionService.readToken(),
      ).thenAnswer((_) async => 'jwt-token');

      final apiClient = ApiClient(
        baseUri: Uri.parse('https://example.test/HabitatInsertion/api'),
        sessionService: sessionService,
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer jwt-token');
          expect(request.headers['Accept'], 'application/json');
          return http.Response('{"ok":true}', 200);
        }),
      );

      final response = await apiClient.getMap('/metier/ping');

      expect(response, {'ok': true});
      verify(() => sessionService.readToken()).called(1);
    },
  );
}
