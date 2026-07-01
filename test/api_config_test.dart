import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/services/api_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    dotenv.clean();
  });

  test('reads API base URL from environment', () {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example.test/HabitatInsertion/api/\n',
    );

    expect(
      ApiConfig.baseUri.toString(),
      'https://example.test/HabitatInsertion/api',
    );
  });

  test('rejects missing API base URL', () {
    dotenv.loadFromString(envString: 'OTHER_VALUE=ignored\n');

    expect(() => ApiConfig.baseUri, throwsA(isA<StateError>()));
  });

  test('rejects non-HTTPS remote API base URL', () {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://example.test/HabitatInsertion/api\n',
    );

    expect(() => ApiConfig.baseUri, throwsA(isA<StateError>()));
  });

  test('rewrites localhost API URL for Android emulator', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://127.0.0.1:8080/api\n',
    );

    expect(ApiConfig.baseUri.toString(), 'http://10.0.2.2:8080/api');
  });
}
