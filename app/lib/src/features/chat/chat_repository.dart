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
    final json = await _api.get<Map<String, dynamic>>('/conversations', query: {'per_page': 50});
    return Paginated.listOf(json, Conversation.fromJson);
  }

  Future<List<Message>> messages(int conversationId, {int? before, int limit = 30}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/conversations/$conversationId/messages',
      query: {'limit': limit, if (before != null) 'before': before},
    );
    return Paginated.listOf(json, Message.fromJson);
  }

  Future<Message> send(int conversationId, {String? body}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/conversations/$conversationId/messages',
      data: FormData.fromMap({if (body != null) 'body': body}),
    );
    return Message.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> markRead(int conversationId) =>
      _api.post('/conversations/$conversationId/read');

  Future<Conversation> createDirect(int userId) async {
    final json = await _api.post<Map<String, dynamic>>('/conversations', data: {
      'type': 'direct',
      'participant_ids': [userId],
    });
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }
}

final chatRepositoryProvider =
    Provider((ref) => ChatRepository(ref.watch(apiClientProvider)));

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).conversations();
});
