import 'package:flutter/material.dart';

import '../theme/app_color.dart';

enum UserRole {
  admin,
  manager,
  staff;

  static UserRole from(String? v) => switch (v) {
    'admin' => admin,
    'manager' => manager,
    _ => staff,
  };

  String get label => switch (this) {
    admin => 'Admin',
    manager => 'Manager',
    staff => 'Staff',
  };

  bool get isManagerOrAdmin => this == admin || this == manager;
}

enum TaskStatus {
  assigned,
  inProgress,
  completed,
  approved,
  revision;

  static TaskStatus from(String? v) => switch (v) {
    'in_progress' => inProgress,
    'completed' => completed,
    'approved' => approved,
    'revision' => revision,
    _ => assigned,
  };

  String get wire => switch (this) {
    inProgress => 'in_progress',
    _ => name,
  };

  String get label => switch (this) {
    assigned => 'Assigned',
    inProgress => 'In Progress',
    completed => 'Completed',
    approved => 'Approved',
    revision => 'Needs Revision',
  };

  Color get color => switch (this) {
    assigned => AppColor.slate,
    inProgress => AppColor.brand,
    completed => AppColor.accent,
    approved => AppColor.success,
    revision => AppColor.danger,
  };

  Color get softColor => switch (this) {
    assigned => AppColor.surfaceMuted,
    inProgress => AppColor.brandSoft,
    completed => AppColor.accentSoft,
    approved => AppColor.successSoft,
    revision => AppColor.dangerSoft,
  };
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  static TaskPriority from(String? v) => switch (v) {
    'low' => low,
    'high' => high,
    'urgent' => urgent,
    _ => medium,
  };

  String get label => switch (this) {
    low => 'Low',
    medium => 'Medium',
    high => 'High',
    urgent => 'Urgent',
  };

  Color get color => switch (this) {
    low => AppColor.priorityLow,
    medium => AppColor.priorityMedium,
    high => AppColor.priorityHigh,
    urgent => AppColor.priorityUrgent,
  };
}

enum ConversationType {
  direct,
  group,
  channel;

  static ConversationType from(String? v) => switch (v) {
    'direct' => direct,
    'channel' => channel,
    _ => group,
  };
}

enum MessageKind {
  text,
  file,
  image,
  voice;

  static MessageKind from(String? v) => switch (v) {
    'file' => file,
    'image' => image,
    'voice' => voice,
    _ => text,
  };
}
