import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  const ApiConfig._();

  static const environmentFile = 'assets/.env.local';
  static const baseUrlEnvKey = 'API_BASE_URL';

  static Future<void> loadEnvironment() async {
    try {
      await dotenv.load(fileName: environmentFile);
    } catch (error) {
      if (kReleaseMode) {
        throw StateError(
          'Configuration API introuvable. '
          'Le fichier $environmentFile doit définir $baseUrlEnvKey.',
        );
      }
    }
  }

  static Uri get baseUri {
    final rawBaseUrl = _readBaseUrl();
    final normalizedBaseUrl = _normalizeBaseUrl(rawBaseUrl);
    final uri = Uri.tryParse(normalizedBaseUrl);

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw StateError(
        '$baseUrlEnvKey doit être une URL absolue valide. '
        'Exemple : https://exemple.fr/HabitatInsertion/api',
      );
    }

    if (uri.scheme != 'https' && !_isLocalDevelopmentUri(uri)) {
      throw StateError(
        '$baseUrlEnvKey doit utiliser HTTPS hors environnement local.',
      );
    }

    return uri;
  }

  static String _readBaseUrl() {
    String? rawBaseUrl;

    try {
      rawBaseUrl = dotenv.maybeGet(baseUrlEnvKey);
    } catch (_) {
      rawBaseUrl = null;
    }

    if (rawBaseUrl == null || rawBaseUrl.trim().isEmpty) {
      throw StateError(
        '$baseUrlEnvKey est absent. '
        'Créez $environmentFile à partir de assets/.env.example.',
      );
    }

    return rawBaseUrl;
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();

    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      normalized = normalized
          .replaceFirst('http://127.0.0.1', 'http://10.0.2.2')
          .replaceFirst('http://localhost', 'http://10.0.2.2');
    }

    return normalized;
  }

  static bool _isLocalDevelopmentUri(Uri uri) {
    return uri.scheme == 'http' &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '10.0.2.2');
  }
}
