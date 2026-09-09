import 'package:dio/dio.dart';
import 'package:cropdect/models/user.dart';
import '../api_client.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();

  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get('/users/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to load user profile: ${e.message}');
    }
  }

  Future<User> updateUser(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.put('/users/me', data: data);
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to update profile: ${e.response?.data['detail'] ?? e.message}');
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _apiClient.dio.delete('/users/me');
    } on DioException catch (e) {
      throw Exception('Failed to delete account: ${e.response?.data['detail'] ?? e.message}');
    }
  }
}

final userService = UserService();
