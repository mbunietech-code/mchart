import 'enums.dart';
import 'user.dart';

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class TaskAttachment {
  TaskAttachment({
    required this.id,
    required this.url,
    required this.fileName,
    this.fileType,
    this.fileSize,
    this.durationSeconds,
    this.uploader,
  });

  final int id;
  final String url;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final int? durationSeconds;
  final User? uploader;

  bool get isImage => (fileType ?? '').startsWith('image/');
  bool get isVoice => (fileType ?? '').startsWith('audio/');
  bool get isVideo => (fileType ?? '').startsWith('video/');
  bool get isDocument => !isImage && !isVoice && !isVideo;

  factory TaskAttachment.fromJson(Map<String, dynamic> j) => TaskAttachment(
    id: (j['id'] as num).toInt(),
    url: j['url'] as String? ?? '',
    fileName: j['file_name'] as String?,
    fileType: j['file_type'] as String?,
    fileSize: (j['file_size'] as num?)?.toInt(),
    durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
    uploader: j['uploader'] is Map ? User.fromJson(j['uploader']) : null,
  );
}

class TaskComment {
  TaskComment({
    required this.id,
    required this.comment,
    required this.isRevisionNote,
    required this.createdAt,
    this.user,
  });

  final int id;
  final String comment;
  final bool isRevisionNote;
  final DateTime createdAt;
  final User? user;

  factory TaskComment.fromJson(Map<String, dynamic> j) => TaskComment(
    id: (j['id'] as num).toInt(),
    comment: j['comment'] as String? ?? '',
    isRevisionNote: j['is_revision_note'] as bool? ?? false,
    createdAt: _date(j['created_at']) ?? DateTime.now(),
    user: j['user'] is Map ? User.fromJson(j['user']) : null,
  );
}

class TaskStatusEvent {
  TaskStatusEvent({
    required this.id,
    this.oldStatus,
    required this.newStatus,
    this.note,
    this.changedBy,
    this.changedAt,
  });

  final int id;
  final String? oldStatus;
  final String newStatus;
  final String? note;
  final User? changedBy;
  final DateTime? changedAt;

  factory TaskStatusEvent.fromJson(Map<String, dynamic> j) => TaskStatusEvent(
    id: (j['id'] as num).toInt(),
    oldStatus: j['old_status'] as String?,
    newStatus: j['new_status'] as String? ?? '',
    note: j['note'] as String?,
    changedBy: j['changed_by'] is Map ? User.fromJson(j['changed_by']) : null,
    changedAt: _date(j['changed_at']),
  );
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.isOverdue,
    this.description,
    this.deadline,
    this.departmentId,
    this.creator,
    this.assignee,
    this.startedAt,
    this.completedAt,
    this.approvedAt,
    this.createdAt,
    this.commentsCount,
    this.attachmentsCount,
    this.allowedTransitions = const [],
    this.attachments = const [],
    this.comments = const [],
    this.statusHistory = const [],
  });

  final int id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final bool isOverdue;
  final DateTime? deadline;
  final int? departmentId;
  final User? creator;
  final User? assignee;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final int? commentsCount;
  final int? attachmentsCount;
  final List<String> allowedTransitions;
  final List<TaskAttachment> attachments;
  final List<TaskComment> comments;
  final List<TaskStatusEvent> statusHistory;

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: (j['id'] as num).toInt(),
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    status: TaskStatus.from(j['status'] as String?),
    priority: TaskPriority.from(j['priority'] as String?),
    isOverdue: j['is_overdue'] as bool? ?? false,
    deadline: _date(j['deadline']),
    departmentId: (j['department_id'] as num?)?.toInt(),
    creator: j['creator'] is Map ? User.fromJson(j['creator']) : null,
    assignee: j['assignee'] is Map ? User.fromJson(j['assignee']) : null,
    startedAt: _date(j['started_at']),
    completedAt: _date(j['completed_at']),
    approvedAt: _date(j['approved_at']),
    createdAt: _date(j['created_at']),
    commentsCount: (j['comments_count'] as num?)?.toInt(),
    attachmentsCount: (j['attachments_count'] as num?)?.toInt(),
    allowedTransitions: (j['allowed_transitions'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    attachments: (j['attachments'] as List? ?? const [])
        .map((e) => TaskAttachment.fromJson(e as Map<String, dynamic>))
        .toList(),
    comments: (j['comments'] as List? ?? const [])
        .map((e) => TaskComment.fromJson(e as Map<String, dynamic>))
        .toList(),
    statusHistory: (j['status_history'] as List? ?? const [])
        .map((e) => TaskStatusEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
