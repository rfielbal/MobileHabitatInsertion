import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'api_config.dart';
import 'api_exception.dart';
import 'auth_session_service.dart';
import 'session_invalidation_notifier.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AuthSessionService sessionService = const AuthSessionService(),
    Uri? baseUri,
  }) : _httpClient = httpClient ?? http.Client(),
       _sessionService = sessionService,
       _baseUri = baseUri ?? ApiConfig.baseUri;

  final http.Client _httpClient;
  final AuthSessionService _sessionService;
  final Uri _baseUri;

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) async {
    final decoded = await getJson(
      path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(message: 'Réponse API inattendue.');
  }

  Future<Object?> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool authenticated = true,
  }) {
    return _sendJson(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final decoded = await _sendJson(
      method: 'POST',
      path: path,
      body: body,
      authenticated: authenticated,
    );

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(message: 'Réponse API inattendue.');
  }

  Future<void> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    await _sendJson(
      method: 'POST',
      path: path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<Map<String, dynamic>> patchMap(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = true,
  }) async {
    final decoded = await _sendJson(
      method: 'PATCH',
      path: path,
      body: body,
      authenticated: authenticated,
    );

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(message: 'Réponse API inattendue.');
  }

  Future<void> patch(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = true,
  }) async {
    await _sendJson(
      method: 'PATCH',
      path: path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<void> delete(String path, {bool authenticated = true}) async {
    await _sendJson(method: 'DELETE', path: path, authenticated: authenticated);
  }

  Future<Object?> postMultipart(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, String> fields = const {},
    bool authenticated = true,
    bool retryOnExpiredToken = true,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path, null));
    final headers = await _headers(authenticated: authenticated);
    headers.remove('Content-Type');

    request.headers.addAll(headers);
    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        filePath,
        filename: p.basename(filePath),
      ),
    );

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _decodeResponse(response);
    } on ApiException catch (error) {
      if (authenticated &&
          retryOnExpiredToken &&
          error.isExpiredAuthentication &&
          await _refreshStoredSession()) {
        return postMultipart(
          path,
          fileField: fileField,
          filePath: filePath,
          fields: fields,
          authenticated: authenticated,
          retryOnExpiredToken: false,
        );
      }

      if (authenticated && error.statusCode == 401) {
        await _invalidateStoredSession();
      }

      rethrow;
    } catch (error) {
      throw _maintenanceExceptionFor(error) ?? error;
    }
  }

  Future<Object?> _sendJson({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    required bool authenticated,
    bool retryOnExpiredToken = true,
  }) async {
    final request = http.Request(method, _uri(path, queryParameters));
    request.headers.addAll(await _headers(authenticated: authenticated));

    if (body != null) {
      request.body = jsonEncode(body);
    }

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      return _decodeResponse(response);
    } on ApiException catch (error) {
      if (authenticated &&
          retryOnExpiredToken &&
          error.isExpiredAuthentication &&
          await _refreshStoredSession()) {
        return _sendJson(
          method: method,
          path: path,
          queryParameters: queryParameters,
          body: body,
          authenticated: authenticated,
          retryOnExpiredToken: false,
        );
      }

      if (authenticated && error.statusCode == 401) {
        await _invalidateStoredSession();
      }

      rethrow;
    } catch (error) {
      throw _maintenanceExceptionFor(error) ?? error;
    }
  }

  Object? _decodeResponse(http.Response response) {
    if (response.statusCode == 204) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    if (response.body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body) as Object?;
    } on FormatException {
      throw ApiException(
        message: 'Réponse API invalide.',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
  }

  ApiException? _maintenanceExceptionFor(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return ApiException.maintenance();
    }

    final normalizedError = error.toString().toLowerCase();
    if (normalizedError.contains('socketexception') ||
        normalizedError.contains('connection refused') ||
        normalizedError.contains('connection reset') ||
        normalizedError.contains('failed host lookup') ||
        normalizedError.contains('network is unreachable')) {
      return ApiException.maintenance();
    }

    return null;
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final token = await _sessionService.readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<bool> _refreshStoredSession() async {
    try {
      final currentSession = await _sessionService.readSession();
      if (currentSession == null ||
          currentSession.email.trim().isEmpty ||
          currentSession.mobileSessionToken.trim().isEmpty ||
          currentSession.isMockSession) {
        return false;
      }

      final request = http.Request('POST', _uri('/mobile/session', null));
      request.headers.addAll(const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        'identifier': currentSession.email,
        'mobileSessionToken': currentSession.mobileSessionToken,
      });

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = response.body.trim().isEmpty
          ? null
          : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final token = (decoded['token'] ?? '').toString();
      final mobileSessionToken =
          (decoded['mobileSessionToken'] ?? currentSession.mobileSessionToken)
              .toString();
      final user = decoded['user'];
      if (token.isEmpty ||
          mobileSessionToken.isEmpty ||
          user is! Map<String, dynamic>) {
        return false;
      }

      await _sessionService.saveSession(
        AccountSession(
          token: token,
          userId: (user['id'] ?? currentSession.userId).toString(),
          email: (user['email'] ?? currentSession.email).toString(),
          firstName: (user['prenom'] ?? currentSession.firstName).toString(),
          lastName: (user['nom'] ?? currentSession.lastName).toString(),
          role: _roleFromApi(user['roles'], fallback: currentSession.role),
          pole: (user['pole'] ?? currentSession.pole).toString(),
          mobileSessionToken: mobileSessionToken,
        ),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _invalidateStoredSession() async {
    await _sessionService.clearSession();
    SessionInvalidationNotifier.instance.notifySessionInvalidated();
  }

  String _roleFromApi(Object? rolesValue, {required String fallback}) {
    final roles = rolesValue is List
        ? rolesValue.map((role) => '$role').toList()
        : <String>[];

    if (roles.contains('ROLE_ADMIN')) {
      return 'admin';
    }
    if (roles.contains('ROLE_MANAGER')) {
      return 'manager';
    }
    if (roles.contains('ROLE_USER')) {
      return 'user';
    }
    return fallback;
  }

  Uri _uri(String path, Map<String, String>? queryParameters) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    return _baseUri.replace(
      path: '$basePath/$cleanPath',
      queryParameters: queryParameters,
    );
  }
}
