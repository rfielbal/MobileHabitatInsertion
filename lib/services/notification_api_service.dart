import 'api_client.dart';
import 'fleet_api_mappers.dart';

class NotificationApiService {
  NotificationApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ApiNotificationPayload>> fetchNotifications() async {
    final response = await _apiClient.getMap('/metier/mes-notifications');
    return FleetApiMappers.itemsFromResponse(
      response,
    ).map(FleetApiMappers.notificationFromJson).toList();
  }

  Future<void> markAsRead(int id) async {
    await _apiClient.postMap('/metier/notifications/$id/lire');
  }

  Future<void> deleteNotification(int id) async {
    await _apiClient.delete('/metier/notifications/$id');
  }
}
