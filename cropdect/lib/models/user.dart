class User {
  final int id;
  final String phone;
  final String? email;
  final String? name;
  final String role;
  final String status;

  User({
    required this.id,
    required this.phone,
    this.email,
    this.name,
    required this.role,
    required this.status,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      email: json['email'],
      name: json['name'],
      role: json['role'] ?? 'FARMER',
      status: json['status'] ?? 'ACTIVE',
    );
  }
}
