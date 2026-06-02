import 'api_client.dart';
import 'auth_session_service.dart';

class AuthApiService {
  AuthApiService({
    ApiClient? apiClient,
    AuthSessionService sessionService = const AuthSessionService(),
  }) : _apiClient = apiClient ?? ApiClient(sessionService: sessionService),
       _sessionService = sessionService;

  final ApiClient _apiClient;
  final AuthSessionService _sessionService;

  Future<AccountSession> signInWithIdentifier(String identifier) async {
    final response = await _apiClient.postMap(
      '/mobile/session',
      authenticated: false,
      body: {'identifier': identifier},
    );

    final token = (response['token'] ?? '').toString();
    final user = response['user'];

    if (token.isEmpty || user is! Map<String, dynamic>) {
      throw const FormatException('Réponse de connexion incomplète.');
    }

    final session = _sessionFromUser(user: user, token: token);

    await _sessionService.saveSession(session);
    return session;
  }

  Future<AccountSession> refreshStoredSession(
    AccountSession currentSession,
  ) async {
    final user = await _apiClient.getMap('/me');
    final session = _sessionFromUser(user: user, token: currentSession.token);

    await _sessionService.saveSession(session);
    return session;
  }

  AccountSession _sessionFromUser({
    required Map<String, dynamic> user,
    required String token,
  }) {
    return AccountSession(
      token: token,
      userId: (user['id'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      firstName: (user['prenom'] ?? 'Utilisateur').toString(),
      lastName: (user['nom'] ?? '').toString(),
      role: _roleFromApi(user['roles']),
      pole: (user['pole'] ?? 'Non défini').toString(),
    );
  }

  String _roleFromApi(Object? rolesValue) {
    final roles = rolesValue is List
        ? rolesValue.map((role) => '$role').toList()
        : <String>[];

    if (roles.contains('ROLE_ADMIN')) {
      return 'admin';
    }
    if (roles.contains('ROLE_MANAGER')) {
      return 'manager';
    }
    return 'user';
  }
}
