import '../models/mobile_update.dart';
import 'api_client.dart';

class MobileUpdateApiService {
  MobileUpdateApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<MobileUpdateInfo> fetchUpdateStatus({
    required int currentVersionCode,
    required String? currentVersionName,
  }) async {
    final queryParameters = <String, String>{
      'versionCode': '$currentVersionCode',
    };

    if (currentVersionName != null && currentVersionName.trim().isNotEmpty) {
      queryParameters['versionName'] = currentVersionName.trim();
    }

    final response = await _apiClient.getMap(
      '/metier/mobile-update',
      queryParameters: queryParameters,
    );

    return MobileUpdateInfo.fromJson(
      response,
      fallbackCurrentVersionCode: currentVersionCode,
      fallbackCurrentVersionName: currentVersionName,
    );
  }
}
