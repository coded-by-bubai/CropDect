import 'package:dio/dio.dart';
import 'package:cropdect/models/notification.dart';
import '../api_client.dart';

class NotificationService {
  final ApiClient _apiClient = ApiClient();

  Future<List<NotificationModel>> getNotifications({bool unreadOnly = false}) async {
    try {
      final response = await _apiClient.dio.get(
        '/notifications/',
        queryParameters: {'unread_only': unreadOnly},
      );
      List<dynamic> data = response.data;
      return data.map((json) => NotificationModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load notifications: ${e.message}');
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _apiClient.dio.put('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw Exception('Failed to mark notification as read: ${e.message}');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _apiClient.dio.delete('/notifications/$notificationId');
    } on DioException catch (e) {
      throw Exception('Failed to delete notification: ${e.message}');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      await _apiClient.dio.delete('/notifications/');
    } on DioException catch (e) {
      throw Exception('Failed to delete all notifications: ${e.message}');
    }
  }
}

final notificationService = NotificationService();
