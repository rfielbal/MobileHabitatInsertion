class MobileUpdateInfo {
  const MobileUpdateInfo({
    required this.apkAvailable,
    required this.updateAvailable,
    required this.currentVersionCode,
    this.currentVersionName,
    this.latestVersionCode,
    this.latestVersionName,
    this.releaseNotes,
    this.apkSizeBytes,
    this.apkSizeLabel,
    this.apkSha256,
    this.uploadedAt,
    this.downloadUrl,
  });

  final bool apkAvailable;
  final bool updateAvailable;
  final int currentVersionCode;
  final String? currentVersionName;
  final int? latestVersionCode;
  final String? latestVersionName;
  final String? releaseNotes;
  final int? apkSizeBytes;
  final String? apkSizeLabel;
  final String? apkSha256;
  final DateTime? uploadedAt;
  final Uri? downloadUrl;

  factory MobileUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required int fallbackCurrentVersionCode,
    required String? fallbackCurrentVersionName,
  }) {
    final currentVersionCode = fallbackCurrentVersionCode;
    final currentVersionName =
        fallbackCurrentVersionName?.trim().isEmpty == true
        ? null
        : fallbackCurrentVersionName?.trim();
    final latestVersionCode = _intValue(json['latestVersionCode']);
    final latestVersionName = _stringValue(json['latestVersionName']);
    final serverUpdateAvailable =
        json['updateAvailable'] == true || json['update_available'] == true;
    final updateAvailable = _isUpdateAvailable(
      serverUpdateAvailable: serverUpdateAvailable,
      currentVersionCode: currentVersionCode,
      currentVersionName: currentVersionName,
      latestVersionCode: latestVersionCode,
      latestVersionName: latestVersionName,
    );

    return MobileUpdateInfo(
      apkAvailable:
          json['apkAvailable'] == true || json['apk_available'] == true,
      updateAvailable: updateAvailable,
      currentVersionCode: currentVersionCode,
      currentVersionName: currentVersionName,
      latestVersionCode: latestVersionCode,
      latestVersionName: latestVersionName,
      releaseNotes: _stringValue(json['releaseNotes']),
      apkSizeBytes: _intValue(json['apkSize']),
      apkSizeLabel: _stringValue(json['apkSizeFormatted']),
      apkSha256: _sha256Value(json['apkSha256']),
      uploadedAt: _dateValue(json['uploadedAt']),
      downloadUrl: _uriValue(json['downloadUrl']),
    );
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool _isUpdateAvailable({
    required bool serverUpdateAvailable,
    required int currentVersionCode,
    required String? currentVersionName,
    required int? latestVersionCode,
    required String? latestVersionName,
  }) {
    if (latestVersionCode != null) {
      if (latestVersionCode != currentVersionCode) {
        return latestVersionCode > currentVersionCode;
      }

      return false;
    }

    if (currentVersionName != null && latestVersionName != null) {
      final comparison = _compareVersionNames(
        latestVersionName,
        currentVersionName,
      );

      if (comparison != 0) {
        return comparison > 0;
      }

      return false;
    }

    return serverUpdateAvailable;
  }

  static int _compareVersionNames(String latest, String current) {
    final latestParts = _versionParts(latest);
    final currentParts = _versionParts(current);
    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var index = 0; index < length; index++) {
      final latestPart = index < latestParts.length ? latestParts[index] : 0;
      final currentPart = index < currentParts.length ? currentParts[index] : 0;

      if (latestPart != currentPart) {
        return latestPart.compareTo(currentPart);
      }
    }

    return latest.trim().compareTo(current.trim());
  }

  static List<int> _versionParts(String value) {
    return value
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  static String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _dateValue(Object? value) {
    final normalized = _stringValue(value);
    return normalized == null ? null : DateTime.tryParse(normalized);
  }

  static Uri? _uriValue(Object? value) {
    final normalized = _stringValue(value);
    if (normalized == null) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }

    return uri;
  }

  static String? _sha256Value(Object? value) {
    final normalized = _stringValue(value)?.toLowerCase();
    if (normalized == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      return null;
    }

    return normalized;
  }
}
