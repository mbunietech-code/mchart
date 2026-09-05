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
    this.typingNames = const [],
  });

  final List<Message> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final List<String> typingNames;

  MessageThreadState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? sending,
    Object? error = _s,
    List<String>? typingNames,
  }) => MessageThreadState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    sending: sending ?? this.sending,
    error: error == _s ? this.error : error as String?,
    typingNames: typingNames ?? this.typingNames,
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
  VoidCallback? _unsubTyping;
  Timer? _typingSendCooldown;
  final Map<int, Timer> _typingExpiry = {};
  final Map<int, String> _typingNames = {};

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
    _unsub = rt.on('private-conversation.$conversationId', 'message.sent', (
      data,
    ) {
      final incoming = Message.fromJson(data);
      if (state.messages.any((m) => m.id == incoming.id)) return;
      state = state.copyWith(messages: [...state.messages, incoming]);
      unawaited(_repo.markRead(conversationId));
      // A message arriving means that sender is done typing.
      _clearTyping(incoming.senderId);
    });
    _unsubTyping = rt.on('private-conversation.$conversationId', 'typing', (
      data,
    ) {
      final userId = (data['user_id'] as num?)?.toInt();
      final name = data['name'] as String?;
      if (userId == null || name == null) return;
      _typingNames[userId] = name;
      state = state.copyWith(typingNames: _typingNames.values.toList());
      _typingExpiry[userId]?.cancel();
      _typingExpiry[userId] = Timer(
        const Duration(seconds: 4),
        () => _clearTyping(userId),
      );
    });
  }

  void _clearTyping(int? userId) {
    if (userId == null || !_typingNames.containsKey(userId)) return;
    _typingExpiry.remove(userId)?.cancel();
    _typingNames.remove(userId);
    state = state.copyWith(typingNames: _typingNames.values.toList());
  }

  /// Call on every composer keystroke — throttled so it posts at most once
  /// every 3s instead of on every keypress.
  void notifyTyping() {
    if (_typingSendCooldown != null) return;
    unawaited(_repo.sendTyping(conversationId));
    _typingSendCooldown = Timer(
      const Duration(seconds: 3),
      () => _typingSendCooldown = null,
    );
  }

  Future<void> send(
    String body, {
    Message? replyTo,
    String? attachmentPath,
    String? attachmentName,
    int? attachmentDurationSeconds,
  }) async {
    final text = body.trim();
    if (text.isEmpty && attachmentPath == null) return;
    if (state.sending) return;
    final me = _ref.read(currentUserProvider);

    final optimistic = Message(
      id: -DateTime.now().millisecondsSinceEpoch,
      conversationId: conversationId,
      kind: MessageKind.text,
      createdAt: DateTime.now(),
      senderId: me?.id,
      sender: me,
      body: text.isEmpty ? null : text,
      replyTo: replyTo == null
          ? null
          : MessageReplyPreview(
              id: replyTo.id,
              senderName: replyTo.sender?.name,
              body: replyTo.body,
              deleted: replyTo.deleted,
            ),
      pending: true,
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      sending: true,
    );

    try {
      final saved = await _repo.send(
        conversationId,
        body: text.isEmpty ? null : text,
        replyToId: replyTo?.id,
        attachmentPath: attachmentPath,
        attachmentName: attachmentName,
        attachmentDurationSeconds: attachmentDurationSeconds,
      );
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

  Future<void> deleteMessage(int messageId) async {
    try {
      await _repo.deleteMessage(conversationId, messageId);
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == messageId)
              Message(
                id: m.id,
                conversationId: m.conversationId,
                kind: m.kind,
                createdAt: m.createdAt,
                senderId: m.senderId,
                sender: m.sender,
                deleted: true,
              )
            else
              m,
        ],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleReaction(
    int messageId,
    String emoji, {
    required bool mine,
  }) async {
    try {
      final updated = mine
          ? await _repo.unreact(conversationId, messageId)
          : await _repo.react(conversationId, messageId, emoji);
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == messageId) updated else m,
        ],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _unsub?.call();
    _unsubTyping?.call();
    _typingSendCooldown?.cancel();
    for (final t in _typingExpiry.values) {
      t.cancel();
    }
    super.dispose();
  }
}

final messageThreadProvider = StateNotifierProvider.autoDispose
    .family<MessageThreadController, MessageThreadState, int>((ref, id) {
      return MessageThreadController(ref, id);
    });
