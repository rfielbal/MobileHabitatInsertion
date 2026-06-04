import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'auth_session_service.dart';

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

  Future<Object?> _sendJson({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    required bool authenticated,
  }) async {
    final request = http.Request(method, _uri(path, queryParameters));
    request.headers.addAll(await _headers(authenticated: authenticated));

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamedResponse);

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

    return jsonDecode(response.body) as Object?;
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
