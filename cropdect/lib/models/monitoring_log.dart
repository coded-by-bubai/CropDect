class MonitoringLog {
  final int id;
  final int diagnosisId;
  final String? imageUrl;
  final String? notes;
  final String healthStatus;
  final bool expertReviewed;
  final int? expertId;
  final String? expertNotes;
  final DateTime createdAt;

  MonitoringLog({
    required this.id,
    required this.diagnosisId,
    this.imageUrl,
    this.notes,
    required this.healthStatus,
    this.expertReviewed = false,
    this.expertId,
    this.expertNotes,
    required this.createdAt,
  });

  factory MonitoringLog.fromJson(Map<String, dynamic> json) {
    return MonitoringLog(
      id: json['id'],
      diagnosisId: json['diagnosis_id'],
      imageUrl: json['image_url'],
      notes: json['notes'],
      healthStatus: json['health_status'] ?? 'NO_CHANGE',
      expertReviewed: json['expert_reviewed'] ?? false,
      expertId: json['expert_id'],
      expertNotes: json['expert_notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
