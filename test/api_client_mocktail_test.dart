import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile_habitat_insertion/services/api_client.dart';
import 'package:mobile_habitat_insertion/services/api_exception.dart';
import 'package:mobile_habitat_insertion/services/auth_session_service.dart';
import 'package:mobile_habitat_insertion/services/session_invalidation_notifier.dart';

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

  test(
    'ApiClient clears the stored session when authenticated JWT is invalid',
    () async {
      final sessionService = MockAuthSessionService();
      when(
        () => sessionService.readToken(),
      ).thenAnswer((_) async => 'stale-jwt-token');
      when(() => sessionService.clearSession()).thenAnswer((_) async {});

      var invalidationEvents = 0;
      void listener() {
        invalidationEvents++;
      }

      SessionInvalidationNotifier.instance.addListener(listener);
      addTearDown(
        () => SessionInvalidationNotifier.instance.removeListener(listener),
      );

      final apiClient = ApiClient(
        baseUri: Uri.parse('https://example.test/HabitatInsertion/api'),
        sessionService: sessionService,
        httpClient: MockClient(
          (_) async =>
              http.Response('{"message":"Session mobile fermée."}', 401),
        ),
      );

      await expectLater(
        apiClient.getMap('/metier/ping'),
        throwsA(isA<ApiException>()),
      );

      verify(() => sessionService.clearSession()).called(1);
      expect(invalidationEvents, 1);
    },
  );

  test('ApiClient returns maintenance message when server is unreachable', () {
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://example.test/HabitatInsertion/api'),
      httpClient: MockClient((_) async {
        throw http.ClientException('Connection refused');
      }),
    );

    expect(
      apiClient.getMap('/metier/ping'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Nous sommes en maintenance, veuillez nous excuser',
        ),
      ),
    );
  });
}
