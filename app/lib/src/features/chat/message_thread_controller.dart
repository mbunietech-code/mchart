import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/enums.dart';
import '../../models/message.dart';
import '../auth/auth_controller.dart';
import 'chat_repository.dart';

class MessageThreadState {
  const MessageThreadState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.error,
  });

  final List<Message> messages;
  final bool loading;
  final bool sending;
  final String? error;

  MessageThreadState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? sending,
    Object? error = _s,
  }) =>
      MessageThreadState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: error == _s ? this.error : error as String?,
      );
  static const _s = Object();
}

class MessageThreadController extends StateNotifier<MessageThreadState> {
  MessageThreadController(this._ref, this.conversationId)
      : super(const MessageThreadState()) {
    _load();
    _subscribe();
  }

  final Ref _ref;
  final int conversationId;
  VoidCallback? _unsub;

  ChatRepository get _repo => _ref.read(chatRepositoryProvider);

  Future<void> _load() async {
    try {
      final messages = await _repo.messages(conversationId);
      state = state.copyWith(messages: messages, loading: false, error: null);
      unawaited(_repo.markRead(conversationId));
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void _subscribe() {
    final rt = _ref.read(realtimeClientProvider)..connect();
    _unsub = rt.on('private-conversation.$conversationId', 'message.sent', (data) {
      final incoming = Message.fromJson(data);
      if (state.messages.any((m) => m.id == incoming.id)) return;
      state = state.copyWith(messages: [...state.messages, incoming]);
      unawaited(_repo.markRead(conversationId));
    });
  }

  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty || state.sending) return;
    final me = _ref.read(currentUserProvider);

    final optimistic = Message(
      id: -DateTime.now().millisecondsSinceEpoch,
      conversationId: conversationId,
      kind: MessageKind.text,
      createdAt: DateTime.now(),
      senderId: me?.id,
      sender: me,
      body: text,
      pending: true,
    );
    state = state.copyWith(messages: [...state.messages, optimistic], sending: true);

    try {
      final saved = await _repo.send(conversationId, body: text);
      state = state.copyWith(
        sending: false,
        messages: [
          for (final m in state.messages)
            if (m.id == optimistic.id) saved else m,
        ],
      );
    } catch (e) {
      state = state.copyWith(
        sending: false,
        error: e.toString(),
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
      );
    }
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _unsub?.call();
    super.dispose();
  }
}

final messageThreadProvider = StateNotifierProvider.autoDispose
    .family<MessageThreadController, MessageThreadState, int>((ref, id) {
  return MessageThreadController(ref, id);
});
