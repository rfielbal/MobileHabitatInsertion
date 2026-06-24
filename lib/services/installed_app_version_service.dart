import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';

class InstalledAppVersion {
  const InstalledAppVersion({
    required this.versionCode,
    required this.versionName,
  });

  final int versionCode;
  final String? versionName;
}

class InstalledAppVersionService {
  const InstalledAppVersionService();

  Future<InstalledAppVersion> read() async {
    final platformData = await PackageInfoPlatform.instance.getAll();
    final versionName = platformData.version.trim();

    return InstalledAppVersion(
      versionCode: int.tryParse(platformData.buildNumber.trim()) ?? 0,
      versionName: versionName.isEmpty ? null : versionName,
    );
  }
}
