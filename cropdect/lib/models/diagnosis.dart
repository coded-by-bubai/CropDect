class Diagnosis {
  final int id;
  final int cropId;
  final String imageUrl;
  final String diagnosisType;
  final double confidence;
  final String severity;
  final String status;
  final String? modelVersion;
  final int? diseaseId;
  final int? pestId;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? label;
  final String? cropName;
  final String? expertNotes;
  final String? expertName;
  final bool? isCorrect;

  Diagnosis({
    required this.id,
    required this.cropId,
    required this.imageUrl,
    required this.diagnosisType,
    required this.confidence,
    required this.severity,
    required this.status,
    this.modelVersion,
    this.diseaseId,
    this.pestId,
    this.latitude,
    this.longitude,
    this.label,
    this.cropName,
    this.expertNotes,
    this.expertName,
    this.isCorrect,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Diagnosis.fromJson(Map<String, dynamic> json) {
    return Diagnosis(
      id: json['id'],
      cropId: json['crop_id'],
      imageUrl: json['image_url'],
      diagnosisType: json['diagnosis_type'],
      confidence: (json['confidence'] as num).toDouble(),
      severity: json['severity'],
      status: json['status'],
      modelVersion: json['model_version'],
      diseaseId: json['disease_id'],
      pestId: json['pest_id'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      label: json['label'],
      cropName: json['crop_name'],
      expertNotes: json['expert_notes'],
      expertName: json['expert_name'],
      isCorrect: json['is_correct'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}


class IPMPlan {
  final int diagnosisId;
  final String diseaseName;
  final String severityWarning;
  final List<String> immediateActions;
  final List<String> culturalPractices;
  final List<String> biologicalControls;
  final List<String> chemicalControls;

  IPMPlan({
    required this.diagnosisId,
    required this.diseaseName,
    required this.severityWarning,
    required this.immediateActions,
    required this.culturalPractices,
    required this.biologicalControls,
    required this.chemicalControls,
  });

  factory IPMPlan.fromJson(Map<String, dynamic> json) {
    return IPMPlan(
      diagnosisId: json['diagnosis_id'],
      diseaseName: json['disease_name'],
      severityWarning: json['severity_warning'],
      immediateActions: List<String>.from(json['immediate_actions']),
      culturalPractices: List<String>.from(json['cultural_practices']),
      biologicalControls: List<String>.from(json['biological_controls']),
      chemicalControls: List<String>.from(json['chemical_controls']),
    );
  }
}
