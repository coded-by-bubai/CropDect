class Farm {
  final int id;
  final int ownerId;
  final String name;
  final double area;
  final String? soilType;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  Farm({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.area,
    this.soilType,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: json['id'] ?? 0,
      ownerId: json['owner_id'] ?? 0,
      name: json['name'] ?? 'Unnamed Farm',
      area: json['area'] != null ? (json['area'] as num).toDouble() : 0.0,
      soilType: json['soil_type'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : 0.0,
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at']) ?? DateTime.now()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? (DateTime.tryParse(json['updated_at']) ?? DateTime.now()) : DateTime.now(),
    );
  }
}
