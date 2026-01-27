class User {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // Converter id para int de forma segura, seja string ou int
      id: _parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      isActive: _parseBool(json['is_active']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
    };
  }

  // Método auxiliar para converter para int de forma segura
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Método auxiliar para converter para bool de forma segura
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) {
      return value == 1;
    }
    return false;
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, email: $email, fullName: $fullName, role: $role, isActive: $isActive}';
  }

  // Método para criar uma cópia com alterações
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? fullName,
    String? role,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}