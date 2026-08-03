import 'package:equatable/equatable.dart';

enum UserRole {
  admin,
  salesperson;

  static UserRole fromJson(String? role) {
    if (role == null) return UserRole.salesperson;
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'salesperson':
      default:
        return UserRole.salesperson;
    }
  }

  String toJson() => name.toLowerCase();
}

class AppUser {
  final String id;
  final String name;
  final String username;
  final String passwordHash;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isSalesperson => role == UserRole.salesperson;

  AppUser copyWith({
    String? id,
    String? name,
    String? username,
    String? passwordHash,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'passwordHash': passwordHash,
      'role': role.toJson(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      role: UserRole.fromJson(json['role'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, username: $username, role: $role, isActive: $isActive, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppUser &&
        other.id == id &&
        other.name == name &&
        other.username == username &&
        other.passwordHash == passwordHash &&
        other.role == role &&
        other.isActive == isActive &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        username.hashCode ^
        passwordHash.hashCode ^
        role.hashCode ^
        isActive.hashCode ^
        createdAt.hashCode;
  }
}
