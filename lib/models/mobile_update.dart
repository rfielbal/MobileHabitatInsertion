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
    final currentVersionCode =
        _intValue(json['currentVersionCode']) ?? fallbackCurrentVersionCode;
    final latestVersionCode = _intValue(json['latestVersionCode']);
    final updateAvailable =
        json['updateAvailable'] == true ||
        (json['update_available'] == true) ||
        (latestVersionCode != null && latestVersionCode > currentVersionCode);

    return MobileUpdateInfo(
      apkAvailable:
          json['apkAvailable'] == true || json['apk_available'] == true,
      updateAvailable: updateAvailable,
      currentVersionCode: currentVersionCode,
      currentVersionName:
          _stringValue(json['currentVersionName']) ??
          fallbackCurrentVersionName,
      latestVersionCode: latestVersionCode,
      latestVersionName: _stringValue(json['latestVersionName']),
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
