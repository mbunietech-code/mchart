import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/providers.dart';
import '../../models/announcement.dart';
import '../../models/paginated.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._api);
  final ApiClient _api;

  Future<List<Announcement>> list({
    AnnouncementCategory? category,
    String? search,
    bool archived = false,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/announcements',
      query: {
        'per_page': 50,
        if (category != null) 'category': category.value,
        if (search != null && search.isNotEmpty) 'search': search,
        if (archived) 'archived': 1,
      },
    );
    return Paginated.listOf(json, Announcement.fromJson);
  }

  Future<int> unreadCount() async {
    final json = await _api.get<Map<String, dynamic>>(
      '/announcements/unread-count',
    );
    return (json['unread'] as num?)?.toInt() ?? 0;
  }

  /// Creates, or updates when [id] is given. Multipart so an image can ride
  /// along; updates go to the POST alias since PHP won't parse multipart
  /// PATCH bodies.
  Future<Announcement> save({
    int? id,
    required AnnouncementCategory category,
    required String title,
    required String body,
    int? departmentId,
    bool pinned = false,
    DateTime? expiresAt,
    String? imagePath,
    String? imageName,
    bool removeImage = false,
  }) async {
    final form = FormData.fromMap({
      'category': category.value,
      'title': title,
      'body': body,
      'department_id': departmentId ?? '',
      'pinned': pinned ? 1 : 0,
      'expires_at': expiresAt?.toUtc().toIso8601String() ?? '',
      if (imagePath != null)
        'image': await MultipartFile.fromFile(imagePath, filename: imageName),
      if (removeImage) 'remove_image': 1,
    });
    final json = await _api.post<Map<String, dynamic>>(
      id == null ? '/announcements' : '/announcements/$id',
      data: form,
    );
    return Announcement.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> setFlags(int id, {bool? pinned, bool? archived}) => _api.patch(
    '/announcements/$id',
    data: {'pinned': ?pinned, 'archived': ?archived},
  );

  Future<void> delete(int id) => _api.delete('/announcements/$id');

  Future<void> markRead(int id) => _api.post('/announcements/$id/read');
}

final announcementRepositoryProvider = Provider(
  (ref) => AnnouncementRepository(ref.watch(apiClientProvider)),
);

class AnnouncementQuery {
  const AnnouncementQuery({
    this.category,
    this.search = '',
    this.archived = false,
  });
  final AnnouncementCategory? category;
  final String search;
  final bool archived;

  AnnouncementQuery copyWith({
    Object? category = _keep,
    String? search,
    bool? archived,
  }) => AnnouncementQuery(
    category: category == _keep
        ? this.category
        : category as AnnouncementCategory?,
    search: search ?? this.search,
    archived: archived ?? this.archived,
  );
  static const _keep = Object();
}

final announcementQueryProvider = StateProvider<AnnouncementQuery>(
  (ref) => const AnnouncementQuery(),
);

final announcementsProvider = FutureProvider<List<Announcement>>((ref) {
  final q = ref.watch(announcementQueryProvider);
  return ref
      .watch(announcementRepositoryProvider)
      .list(category: q.category, search: q.search, archived: q.archived);
});

/// Badge on the Status nav item. Refetched on a timer when there's no
/// WebSocket; a new-announcement notification also invalidates it.
final announcementUnreadProvider = FutureProvider<int>((ref) {
  if (!Env.realtimeEnabled) {
    final t = Timer(const Duration(seconds: 60), ref.invalidateSelf);
    ref.onDispose(t.cancel);
  }
  return ref.watch(announcementRepositoryProvider).unreadCount();
});

String announcementImageUrl(String url) =>
    url.startsWith('http') ? url : '${Env.apiBaseUrl}$url';
