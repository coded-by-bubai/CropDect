import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cropdect/api_client.dart';
import 'package:cropdect/models/monitoring_log.dart';

class MonitoringService {
  Future<List<MonitoringLog>> getMonitoringLogs(int diagnosisId) async {
    try {
      final response = await apiClient.get('/monitoring/$diagnosisId/logs');
      final data = response.data as List;
      return data.map((e) => MonitoringLog.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load monitoring logs: $e');
    }
  }

  Future<MonitoringLog> addMonitoringLog({
    required int diagnosisId,
    required String healthStatus,
    String? notes,
    File? imageFile,
  }) async {
    try {
      final formDataMap = <String, dynamic>{
        'health_status': healthStatus,
      };

      if (notes != null && notes.isNotEmpty) {
        formDataMap['notes'] = notes;
      }

      if (imageFile != null) {
        formDataMap['file'] = await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        );
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await apiClient.post(
        '/monitoring/$diagnosisId/logs',
        data: formData,
      );

      return MonitoringLog.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to add monitoring log: $e');
    }
  }

  Future<MonitoringLog> submitExpertReview({
    required int logId,
    required String expertNotes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'expert_notes': expertNotes,
      });

      final response = await apiClient.post(
        '/monitoring/logs/$logId/expert-review',
        data: formData,
      );

      return MonitoringLog.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to submit expert review: $e');
    }
  }
}

final monitoringService = MonitoringService();
