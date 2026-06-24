import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/services/installed_app_version_service.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';

void main() {
  final originalPlatform = PackageInfoPlatform.instance;

  tearDown(() {
    PackageInfoPlatform.instance = originalPlatform;
  });

  test(
    'installed app version is read fresh from platform every time',
    () async {
      final platform = _FakePackageInfoPlatform([
        _packageInfo(version: '1.0.3', buildNumber: '3'),
        _packageInfo(version: '1.0.4', buildNumber: '4'),
      ]);
      PackageInfoPlatform.instance = platform;

      const service = InstalledAppVersionService();

      final firstRead = await service.read();
      final secondRead = await service.read();

      expect(firstRead.versionName, '1.0.3');
      expect(firstRead.versionCode, 3);
      expect(secondRead.versionName, '1.0.4');
      expect(secondRead.versionCode, 4);
      expect(platform.calls, 2);
    },
  );
}

PackageInfoData _packageInfo({
  required String version,
  required String buildNumber,
}) {
  return PackageInfoData(
    appName: 'Wheello',
    packageName: 'com.example.mobile_habitat_insertion',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
}

class _FakePackageInfoPlatform extends PackageInfoPlatform {
  _FakePackageInfoPlatform(List<PackageInfoData> responses)
    : _responses = Queue<PackageInfoData>.of(responses);

  final Queue<PackageInfoData> _responses;
  int calls = 0;

  @override
  Future<PackageInfoData> getAll({String? baseUrl}) async {
    calls++;
    return _responses.removeFirst();
  }
}
