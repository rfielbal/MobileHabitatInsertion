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
    final mobileSessionToken = (response['mobileSessionToken'] ?? '')
        .toString();
    final user = response['user'];

    if (token.isEmpty ||
        mobileSessionToken.isEmpty ||
        user is! Map<String, dynamic>) {
      throw const FormatException('Réponse de connexion incomplète.');
    }

    final session = _sessionFromUser(
      user: user,
      token: token,
      mobileSessionToken: mobileSessionToken,
    );

    await _sessionService.saveSession(session);
    return session;
  }

  Future<AccountSession> refreshStoredSession(
    AccountSession currentSession,
  ) async {
    final user = await _apiClient.getMap('/me');
    final session = _sessionFromUser(
      user: user,
      token: currentSession.token,
      mobileSessionToken: currentSession.mobileSessionToken,
    );

    await _sessionService.saveSession(session);
    return session;
  }

  Future<void> signOut() async {
    final session = await _sessionService.readSession();
    if (session == null || session.isMockSession) {
      await _sessionService.clearSession();
      return;
    }

    if (session.mobileSessionToken.trim().isNotEmpty) {
      await _apiClient.post(
        '/mobile/session/logout',
        authenticated: false,
        body: {
          'identifier': session.email,
          'mobileSessionToken': session.mobileSessionToken,
        },
      );
    }

    await _sessionService.clearSession();
  }

  AccountSession _sessionFromUser({
    required Map<String, dynamic> user,
    required String token,
    required String mobileSessionToken,
  }) {
    return AccountSession(
      token: token,
      userId: (user['id'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      firstName: (user['prenom'] ?? 'Utilisateur').toString(),
      lastName: (user['nom'] ?? '').toString(),
      role: _roleFromApi(user['roles']),
      pole: (user['pole'] ?? 'Non défini').toString(),
      mobileSessionToken: mobileSessionToken,
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
