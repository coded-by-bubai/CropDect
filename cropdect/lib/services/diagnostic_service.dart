import 'package:cropdect/api_client.dart';
import 'package:cropdect/models/diagnosis.dart';

class DiagnosticService {
  Future<IPMPlan> getIpmPlan(int diagnosisId) async {
    try {
      final response = await apiClient.get('/diagnostics/$diagnosisId/ipm-plan');
      return IPMPlan.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load IPM plan: $e');
    }
  }

  Future<List<Diagnosis>> getDiagnosesByCrop(int cropId) async {
    try {
      final response = await apiClient.get('/diagnostics/', queryParameters: {'crop_id': cropId});
      final data = response.data as List;
      return data.map((e) => Diagnosis.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load diagnoses: $e');
    }
  }

  Future<List<Diagnosis>> getDiagnosticHistory() async {
    try {
      final response = await apiClient.get('/diagnostics/history');
      final data = response.data as List;
      return data.map((e) => Diagnosis.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load diagnosis history: $e');
    }
  }

  Future<void> requestExpertReview(int diagnosisId) async {
    try {
      await apiClient.post('/diagnostics/$diagnosisId/request-review');
    } catch (e) {
      throw Exception('Failed to request expert review: $e');
    }
  }

  Future<void> deleteDiagnosis(int diagnosisId) async {
    try {
      await apiClient.delete('/diagnostics/$diagnosisId');
    } catch (e) {
      throw Exception('Failed to delete diagnosis: $e');
    }
  }
}

final diagnosticService = DiagnosticService();
