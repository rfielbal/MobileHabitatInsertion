import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  const ApiConfig._();

  static const _fallbackBaseUrl =
      'https://4743.s3.nuage-peda.fr/HabitatInsertion/api';

  static Uri get baseUri {
    var rawBaseUrl = _fallbackBaseUrl;

    try {
      rawBaseUrl =
          dotenv.maybeGet('API_BASE_URL', fallback: _fallbackBaseUrl) ??
          _fallbackBaseUrl;
    } catch (_) {
      rawBaseUrl = _fallbackBaseUrl;
    }

    return Uri.parse(_normalizeBaseUrl(rawBaseUrl));
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
}
