DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.isRead,
    required this.createdAt,
    this.body,
    this.referenceType,
    this.referenceId,
    this.data = const {},
  });

  final int id;
  final String type;
  final String title;
  final String? body;
  final String? referenceType;
  final int? referenceId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  bool get isTaskRelated =>
      referenceType == 'Task' || (data['task_id'] != null);
  int? get taskId => (data['task_id'] as num?)?.toInt();
  int? get conversationId => (data['conversation_id'] as num?)?.toInt();

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: (j['id'] as num).toInt(),
    type: j['type'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String?,
    referenceType: j['reference_type'] as String?,
    referenceId: (j['reference_id'] as num?)?.toInt(),
    data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    isRead: j['is_read'] as bool? ?? false,
    createdAt: _date(j['created_at']) ?? DateTime.now(),
  );

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    referenceType: referenceType,
    referenceId: referenceId,
    data: data,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
