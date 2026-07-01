import 'dart:convert';

import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.details});

  static const maintenanceMessage =
      'Nous sommes en maintenance, veuillez nous excuser';

  final String message;
  final int? statusCode;
  final Object? details;

  bool get isExpiredAuthentication {
    final normalizedMessage = message.toLowerCase();
    return statusCode == 401 &&
        (normalizedMessage.contains('expired jwt token') ||
            normalizedMessage.contains('session expirée'));
  }

  factory ApiException.fromResponse({
    required int statusCode,
    required String body,
  }) {
    if (statusCode >= 500 && !kDebugMode) {
      return const ApiException(message: maintenanceMessage, statusCode: 503);
    }

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

  factory ApiException.maintenance() {
    return const ApiException(message: maintenanceMessage, statusCode: 503);
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
      return maintenanceMessage;
    }

    return plainBody.isEmpty ? 'Erreur API' : _normalizeMessage(plainBody);
  }

  static String _normalizeMessage(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('expired jwt token') ||
        (lowerMessage.contains('jwt') && lowerMessage.contains('expired'))) {
      return 'Session expirée. Reconnexion en cours, réessayez si nécessaire.';
    }

    if (_isUploadLimitMessage(lowerMessage)) {
      final serverLimit = _uploadLimitFromMessage(message);
      if (serverLimit != null) {
        return 'La vidéo dépasse la limite actuellement acceptée par le serveur (${_formatBytes(serverLimit)}).';
      }

      return 'La vidéo dépasse la limite actuellement acceptée par le serveur.';
    }

    if (message.contains('trying to encode the JWT token') ||
        message.contains('private key/passphrase') ||
        message.contains('Signature key') ||
        message.contains('lexik_jwt_authentication.signature_key')) {
      return 'Connexion impossible : la clé privée JWT ou sa passphrase est mal configurée côté serveur.';
    }

    if (message.contains('DateTimeImmutable') &&
        message.contains('Doctrine\\DBAL\\Types\\DateTimeType')) {
      return 'Réservation impossible : l’API reçoit une date valide, mais le backend doit convertir ses dates en DateTime mutable avant l’enregistrement.';
    }

    return message;
  }

  static bool _isUploadLimitMessage(String message) {
    return (message.contains('post content-length') &&
            message.contains('exceeds the limit')) ||
        message.contains('post_max_size') ||
        message.contains('upload_max_filesize') ||
        message.contains('allowed memory size') ||
        (message.contains('content-length') &&
            message.contains('vidéo') &&
            message.contains('limite'));
  }

  static int? _uploadLimitFromMessage(String message) {
    final match = RegExp(
      r'exceeds the limit of (\d+) bytes',
      caseSensitive: false,
    ).firstMatch(message);

    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1) ?? '');
  }

  static String _formatBytes(int bytes) {
    const megaByte = 1024 * 1024;

    if (bytes >= megaByte) {
      final value = bytes / megaByte;
      final formatted = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1).replaceAll('.', ',');
      return '$formatted Mo';
    }

    return '$bytes octets';
  }
}
