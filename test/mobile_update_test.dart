import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/models/mobile_update.dart';

void main() {
  test(
    'mobile update is ignored when installed build matches latest build',
    () {
      final info = MobileUpdateInfo.fromJson(
        {
          'apkAvailable': true,
          'updateAvailable': true,
          'currentVersionCode': 1,
          'currentVersionName': '1.0.0',
          'latestVersionCode': 3,
          'latestVersionName': '1.0.3',
        },
        fallbackCurrentVersionCode: 3,
        fallbackCurrentVersionName: '1.0.3',
      );

      expect(info.currentVersionCode, 3);
      expect(info.currentVersionName, '1.0.3');
      expect(info.updateAvailable, isFalse);
    },
  );

  test('mobile update is available only when latest build is newer', () {
    final info = MobileUpdateInfo.fromJson(
      {
        'apkAvailable': true,
        'updateAvailable': true,
        'latestVersionCode': 3,
        'latestVersionName': '1.0.3',
      },
      fallbackCurrentVersionCode: 2,
      fallbackCurrentVersionName: '1.0.2',
    );

    expect(info.updateAvailable, isTrue);
  });

  test(
    'mobile update falls back to version names when build code is missing',
    () {
      final info = MobileUpdateInfo.fromJson(
        {
          'apkAvailable': true,
          'updateAvailable': false,
          'latestVersionName': '1.0.4',
        },
        fallbackCurrentVersionCode: 3,
        fallbackCurrentVersionName: '1.0.3',
      );

      expect(info.updateAvailable, isTrue);
    },
  );
}
