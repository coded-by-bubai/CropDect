import 'package:cropdect/api_client.dart';
import 'package:cropdect/models/farm.dart';
import 'package:cropdect/models/weather.dart';

class FarmService {
  Future<List<Farm>> getFarms() async {
    try {
      final response = await apiClient.get('/farms/');
      final data = response.data as List;
      return data.map((e) => Farm.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load farms: $e');
    }
  }

  Future<Farm> createFarm(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.post('/farms/', data: data);
      return Farm.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create farm: $e');
    }
  }

  Future<Weather> getFarmWeather(int farmId) async {
    try {
      final response = await apiClient.get('/farms/$farmId/weather');
      return Weather.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load weather: $e');
    }
  }

  Future<Farm> updateFarm(int farmId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.put('/farms/$farmId', data: data);
      return Farm.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update farm: $e');
    }
  }

  Future<void> deleteFarm(int farmId) async {
    try {
      await apiClient.delete('/farms/$farmId');
    } catch (e) {
      throw Exception('Failed to delete farm: $e');
    }
  }
}

final farmService = FarmService();
