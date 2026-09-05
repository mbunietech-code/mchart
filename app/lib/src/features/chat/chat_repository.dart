import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/message.dart';
import '../../models/paginated.dart';

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<Conversation>> conversations() async {
    final json = await _api.get<Map<String, dynamic>>(
      '/conversations',
      query: {'per_page': 50},
    );
    return Paginated.listOf(json, Conversation.fromJson);
  }

  Future<List<Message>> messages(
    int conversationId, {
    int? before,
    int limit = 30,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/conversations/$conversationId/messages',
      query: {'limit': limit, if (before != null) 'before': before},
    );
    return Paginated.listOf(json, Message.fromJson);
  }

  Future<Message> send(
    int conversationId, {
    String? body,
    int? replyToId,
    String? attachmentPath,
    String? attachmentName,
    int? attachmentDurationSeconds,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/conversations/$conversationId/messages',
      data: FormData.fromMap({
        if (body != null) 'body': body,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (attachmentPath != null)
          'attachments[]': await MultipartFile.fromFile(
            attachmentPath,
            filename: attachmentName,
          ),
        if (attachmentDurationSeconds != null)
          'attachment_meta[0][duration_seconds]': attachmentDurationSeconds,
      }),
    );
    return Message.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> deleteMessage(int conversationId, int messageId) =>
      _api.delete('/conversations/$conversationId/messages/$messageId');

  Future<Message> react(int conversationId, int messageId, String emoji) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/conversations/$conversationId/messages/$messageId/reactions',
      data: {'emoji': emoji},
    );
    return Message.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Message> unreact(int conversationId, int messageId) async {
    final json = await _api.delete<Map<String, dynamic>>(
      '/conversations/$conversationId/messages/$messageId/reactions',
    );
    return Message.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> markRead(int conversationId) =>
      _api.post('/conversations/$conversationId/read');

  Future<void> sendTyping(int conversationId) =>
      _api.post('/conversations/$conversationId/typing');

  Future<Conversation> createDirect(int userId) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/conversations',
      data: {
        'type': 'direct',
        'participant_ids': [userId],
      },
    );
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Conversation> createGroup(String name, List<int> userIds) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/conversations',
      data: {'type': 'group', 'name': name, 'participant_ids': userIds},
    );
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Conversation> renameGroup(int conversationId, String name) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/conversations/$conversationId',
      data: {'name': name},
    );
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Conversation> addParticipants(
    int conversationId,
    List<int> userIds,
  ) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/conversations/$conversationId/participants',
      data: {'user_ids': userIds},
    );
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> removeParticipant(int conversationId, int userId) =>
      _api.delete('/conversations/$conversationId/participants/$userId');
}

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).conversations();
});
