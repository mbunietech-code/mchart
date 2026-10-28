import 'package:flutter/material.dart';

import '../theme/app_color.dart';
import 'user.dart';

enum AnnouncementCategory {
  meeting('meeting', 'Meeting', Icons.groups_rounded, AppColor.brand),
  notice('notice', 'Notice', Icons.campaign_rounded, AppColor.navy),
  event('event', 'Event', Icons.celebration_rounded, AppColor.success),
  reminder('reminder', 'Reminder', Icons.alarm_rounded, AppColor.accent),
  urgent('urgent', 'Urgent', Icons.priority_high_rounded, AppColor.danger);

  const AnnouncementCategory(this.value, this.label, this.icon, this.color);
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  static AnnouncementCategory parse(String? v) => values.firstWhere(
    (c) => c.value == v,
    orElse: () => AnnouncementCategory.notice,
  );
}

class Announcement {
  const Announcement({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.imageUrl,
    this.pinned = false,
    this.archived = false,
    this.expiresAt,
    this.departmentId,
    this.department,
    this.author,
    this.isRead = false,
    this.readCount,
    this.canManage = false,
  });

  final int id;
  final AnnouncementCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? imageUrl;
  final bool pinned;
  final bool archived;
  final DateTime? expiresAt;
  final int? departmentId;
  final Department? department;
  final User? author;
  final bool isRead;

  /// Only present for the author and admins.
  final int? readCount;
  final bool canManage;

  /// Company-wide or the department's name.
  String get audienceLabel =>
      departmentId == null ? 'Everyone' : (department?.name ?? 'Department');

  Announcement copyWith({bool? isRead}) => Announcement(
    id: id,
    category: category,
    title: title,
    body: body,
    createdAt: createdAt,
    imageUrl: imageUrl,
    pinned: pinned,
    archived: archived,
    expiresAt: expiresAt,
    departmentId: departmentId,
    department: department,
    author: author,
    isRead: isRead ?? this.isRead,
    readCount: readCount,
    canManage: canManage,
  );

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
    id: (j['id'] as num).toInt(),
    category: AnnouncementCategory.parse(j['category'] as String?),
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    imageUrl: j['image_url'] as String?,
    pinned: j['pinned'] as bool? ?? false,
    archived: j['archived'] as bool? ?? false,
    expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? '')?.toLocal(),
    departmentId: (j['department_id'] as num?)?.toInt(),
    department: j['department'] is Map<String, dynamic>
        ? Department.fromJson(j['department'] as Map<String, dynamic>)
        : null,
    author: j['author'] is Map<String, dynamic>
        ? User.fromJson(j['author'] as Map<String, dynamic>)
        : null,
    isRead: j['is_read'] as bool? ?? false,
    readCount: (j['read_count'] as num?)?.toInt(),
    canManage: j['can_manage'] as bool? ?? false,
  );
}
