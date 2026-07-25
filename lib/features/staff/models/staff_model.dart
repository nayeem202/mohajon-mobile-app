import 'package:flutter/material.dart';

class StaffMember {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String email;
  final String username;
  final String password;
  final bool active;
  final String createdAt;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    this.email = '',
    required this.username,
    this.password = '',
    this.active = true,
    required this.createdAt,
  });

  StaffMember copyWith({
    String? id,
    String? name,
    String? role,
    String? phone,
    String? email,
    String? username,
    String? password,
    bool? active,
    String? createdAt,
    bool clearPassword = false,
  }) {
    return StaffMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      username: username ?? this.username,
      password: clearPassword ? '' : (password ?? this.password),
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'username': username,
        'password': password,
        'active': active,
        'createdAt': createdAt,
      };

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        phone: (json['phone'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        username: json['username'] as String,
        password: (json['password'] as String?) ?? '',
        active: (json['active'] as bool?) ?? true,
        createdAt: json['createdAt'] as String,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (parts.length == 1 && parts.first.length >= 2) {
      return parts.first.substring(0, 2).toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color get avatarColor {
    const colors = [
      Color(0xFFF97316),
      Color(0xFF0F766E),
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFF059669),
      Color(0xFFDB2777),
      Color(0xFFD97706),
      Color(0xFF0891B2),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
