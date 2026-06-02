import 'dart:convert';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  factory ApiException.fromResponse({
    required int statusCode,
    required String body,
  }) {
    var message = 'Erreur API';
    Object? details;

    if (body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        details = decoded;

        if (decoded is Map<String, dynamic>) {
          message = _normalizeMessage(
            (decoded['detail'] ??
                    decoded['message'] ??
                    decoded['title'] ??
                    decoded['error'] ??
                    message)
                .toString(),
          );
        }
      } catch (_) {
        message = _messageFromPlainBody(body);
        details = body;
      }
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      details: details,
    );
  }

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return '$message ($statusCode)';
  }

  static String _messageFromPlainBody(String body) {
    final plainBody = body
        .replaceAll(RegExp('<[^>]*>'), ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (plainBody.contains('Composer detected issues in your platform') &&
        plainBody.contains('PHP version')) {
      return 'API indisponible : la version PHP du serveur est incompatible avec Composer.';
    }

    return plainBody.isEmpty ? 'Erreur API' : _normalizeMessage(plainBody);
  }

  static String _normalizeMessage(String message) {
    if (message.contains('trying to encode the JWT token') ||
        message.contains('private key/passphrase') ||
        message.contains('Signature key') ||
        message.contains('lexik_jwt_authentication.signature_key')) {
      return 'Connexion impossible : la clé privée JWT ou sa passphrase est mal configurée côté serveur.';
    }

    return message;
  }
}
