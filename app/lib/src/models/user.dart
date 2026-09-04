import 'enums.dart';

class Department {
  Department({required this.id, required this.name, this.description, this.usersCount});

  final int id;
  final String name;
  final String? description;
  final int? usersCount;

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        description: j['description'] as String?,
        usersCount: (j['users_count'] as num?)?.toInt(),
      );
}

class User {
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.departmentId,
    this.department,
    this.lastSeenAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final String status;
  final int? departmentId;
  final Department? department;
  final DateTime? lastSeenAt;

  bool get isActive => status == 'active';
  bool get isOnline =>
      lastSeenAt != null && DateTime.now().difference(lastSeenAt!).inMinutes < 3;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String?,
        role: UserRole.from(j['role'] as String?),
        status: j['status'] as String? ?? 'active',
        departmentId: (j['department_id'] as num?)?.toInt(),
        department: j['department'] is Map
            ? Department.fromJson(j['department'] as Map<String, dynamic>)
            : null,
        lastSeenAt: _date(j['last_seen_at']),
      );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
