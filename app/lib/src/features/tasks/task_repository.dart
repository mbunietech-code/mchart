import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/enums.dart';
import '../../models/paginated.dart';
import '../../models/task.dart';

class TaskRepository {
  TaskRepository(this._api);
  final ApiClient _api;

  Future<Paginated<Task>> list({
    TaskStatus? status,
    TaskPriority? priority,
    int? assignedTo,
    int? departmentId,
    bool overdue = false,
    String? search,
    String sort = 'created_at',
    String direction = 'desc',
    int page = 1,
    int perPage = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/tasks',
      query: {
        if (status != null) 'status': status.wire,
        if (priority != null) 'priority': priority.name,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (departmentId != null) 'department_id': departmentId,
        if (overdue) 'overdue': 1,
        if (search != null && search.isNotEmpty) 'search': search,
        'sort': sort,
        'direction': direction,
        'page': page,
        'per_page': perPage,
      },
    );
    return Paginated.fromJson(json, Task.fromJson);
  }

  Future<Task> show(int id) async {
    final json = await _api.get<Map<String, dynamic>>('/tasks/$id');
    return Task.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Task> create(Map<String, dynamic> body) async {
    final json = await _api.post<Map<String, dynamic>>('/tasks', data: body);
    return Task.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Task> update(int id, Map<String, dynamic> body) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/tasks/$id',
      data: body,
    );
    return Task.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Task> transition(int id, String action, {String? note}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/tasks/$id/$action',
      data: note == null ? null : {'note': note},
    );
    return Task.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Admin/manager/creator override to any status, bypassing workflow rules.
  Future<Task> setStatus(int id, String status) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/tasks/$id/set-status',
      data: {'status': status},
    );
    return Task.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<TaskComment> comment(int id, String comment) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/tasks/$id/comments',
      data: {'comment': comment},
    );
    return TaskComment.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<TaskAttachment> uploadAttachment(
    int taskId,
    String filePath, {
    String? fileName,
    int? durationSeconds,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    });
    final json = await _api.post<Map<String, dynamic>>(
      '/tasks/$taskId/attachments',
      data: form,
    );
    return TaskAttachment.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> deleteAttachment(int taskId, int attachmentId) =>
      _api.delete('/tasks/$taskId/attachments/$attachmentId');
}

final taskRepositoryProvider = Provider(
  (ref) => TaskRepository(ref.watch(apiClientProvider)),
);

/// Board filter state.
class TaskFilter {
  const TaskFilter({
    this.status,
    this.search = '',
    this.mineOnly = false,
    this.overdue = false,
  });
  final TaskStatus? status;
  final String search;
  final bool mineOnly;
  final bool overdue;

  TaskFilter copyWith({
    Object? status = _s,
    String? search,
    bool? mineOnly,
    bool? overdue,
  }) => TaskFilter(
    status: status == _s ? this.status : status as TaskStatus?,
    search: search ?? this.search,
    mineOnly: mineOnly ?? this.mineOnly,
    overdue: overdue ?? this.overdue,
  );
  static const _s = Object();
}

final taskFilterProvider = StateProvider<TaskFilter>(
  (ref) => const TaskFilter(),
);

/// The board loads all visible tasks (paginated large) and groups them client-side.
final taskBoardProvider = FutureProvider<List<Task>>((ref) async {
  final f = ref.watch(taskFilterProvider);
  final repo = ref.watch(taskRepositoryProvider);
  final page = await repo.list(
    search: f.search,
    overdue: f.overdue,
    perPage: 100,
    sort: 'deadline',
    direction: 'asc',
  );
  return page.items;
});

final taskDetailProvider = FutureProvider.family<Task, int>((ref, id) {
  return ref.watch(taskRepositoryProvider).show(id);
});
