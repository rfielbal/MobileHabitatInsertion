import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/mobile_update.dart';
import '../services/mobile_update_api_service.dart';

class MobileUpdateStore {
  const MobileUpdateStore._();

  static final ValueNotifier<MobileUpdateInfo?> info =
      ValueNotifier<MobileUpdateInfo?>(null);
  static final ValueNotifier<bool> loading = ValueNotifier(false);
  static final ValueNotifier<String?> error = ValueNotifier(null);
  static final ValueNotifier<DateTime?> lastCheckedAt =
      ValueNotifier<DateTime?>(null);

  static final MobileUpdateApiService _apiService = MobileUpdateApiService();
  static bool _refreshing = false;

  static int get pendingCount {
    return info.value?.updateAvailable == true ? 1 : 0;
  }

  static Future<void> refresh() async {
    if (_refreshing) {
      return;
    }

    _refreshing = true;
    loading.value = true;
    error.value = null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersionName = packageInfo.version.trim().isEmpty
          ? null
          : packageInfo.version.trim();

      info.value = await _apiService.fetchUpdateStatus(
        currentVersionCode: currentVersionCode,
        currentVersionName: currentVersionName,
      );
      lastCheckedAt.value = DateTime.now();
    } catch (_) {
      error.value = 'Nous sommes en maintenance, veuillez nous excuser';
    } finally {
      loading.value = false;
      _refreshing = false;
    }
  }

  static void reset() {
    info.value = null;
    loading.value = false;
    error.value = null;
    lastCheckedAt.value = null;
    _refreshing = false;
  }
}
