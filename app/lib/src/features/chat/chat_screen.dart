import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/env.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../models/enums.dart';
import '../../models/message.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/pills.dart';
import '../../widgets/primitives.dart';
import '../auth/auth_controller.dart';
import 'chat_attachment_picker.dart';
import 'chat_pickers.dart';
import 'chat_repository.dart';
import 'group_info_sheet.dart';
import 'message_thread_controller.dart';
import 'new_chat_sheet.dart';

const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.conversationId});
  final int? conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  int? _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.conversationId;
  }

  @override
  void didUpdateWidget(covariant ChatScreen old) {
    super.didUpdateWidget(old);
    if (widget.conversationId != null && widget.conversationId != _selected) {
      setState(() => _selected = widget.conversationId);
    }
  }

  Future<void> _startNewChat() async {
    final conversation = await showNewChatSheet(context);
    if (conversation == null || !mounted) return;
    setState(() => _selected = conversation.id);
    context.go('/chats?c=${conversation.id}');
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final me = ref.watch(currentUserProvider)!;

    final listPane = _ListPane(
      conversations: conversations,
      selectedId: _selected,
      search: _search,
      currentUserId: me.id,
      onSearch: (v) => setState(() => _search = v),
      onNewChat: _startNewChat,
      onSelect: (id) {
        setState(() => _selected = id);
        context.go('/chats?c=$id');
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow screens can't show the conversation list and the thread
        // side by side — show one at a time, like a phone messaging app.
        if (constraints.maxWidth < AppLayout.mobileBreakpoint) {
          return _selected == null
              ? listPane
              : _ThreadPane(
                  key: ValueKey(_selected),
                  conversationId: _selected!,
                  currentUserId: me.id,
                  onBack: () => setState(() => _selected = null),
                );
        }

        return Row(
          children: [
            SizedBox(width: AppLayout.listPaneWidth, child: listPane),
            const VerticalDivider(width: 1),
            Expanded(
              child: _selected == null
                  ? const _NoSelection()
                  : _ThreadPane(
                      key: ValueKey(_selected),
                      conversationId: _selected!,
                      currentUserId: me.id,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Left list pane
// ---------------------------------------------------------------------------

class _ListPane extends ConsumerWidget {
  const _ListPane({
    required this.conversations,
    required this.selectedId,
    required this.search,
    required this.currentUserId,
    required this.onSearch,
    required this.onSelect,
    required this.onNewChat,
  });

  final AsyncValue<List<Conversation>> conversations;
  final int? selectedId;
  final String search;
  final int currentUserId;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref
        .watch(realtimeConnectedProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Container(
      color: AppColor.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: onSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search chats and channels',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      fillColor: AppColor.surfaceMuted,
                    ),
                  ),
                ),
                Gap.sm,
                IconButton(
                  onPressed: onNewChat,
                  tooltip: 'New conversation',
                  icon: const Icon(Icons.add_comment_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColor.brand,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.md,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: conversations.maybeWhen(
                    data: (list) => Text(
                      'ALL CHATS ${list.length}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    orElse: () => Text(
                      'CHATS',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                LivePill(
                  online: connected,
                  onlineLabel: 'Reverb Active',
                  offlineLabel: 'Offline',
                ),
              ],
            ),
          ),
          Expanded(
            child: conversations.when(
              loading: () => const LoadingBlock(height: 300),
              error: (e, _) => ErrorBlock(
                message: '$e',
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
              data: (list) {
                final filtered = search.isEmpty
                    ? list
                    : list
                          .where(
                            (c) => c
                                .titleFor(currentUserId)
                                .toLowerCase()
                                .contains(search.toLowerCase()),
                          )
                          .toList();
                final showArchived = ref.watch(showArchivedProvider);
                final archivedCount = filtered.where((c) => c.archived).length;
                final visible = filtered
                    .where((c) => c.archived == showArchived)
                    .toList();
                final channels = visible
                    .where((c) => c.type != ConversationType.direct)
                    .toList();
                final dms = visible
                    .where((c) => c.type == ConversationType.direct)
                    .toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No conversations',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    if (showArchived || archivedCount > 0)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          showArchived
                              ? Icons.arrow_back_rounded
                              : Icons.archive_outlined,
                          size: 20,
                        ),
                        title: Text(
                          showArchived
                              ? 'Back to chats'
                              : 'Archived ($archivedCount)',
                        ),
                        onTap: () =>
                            ref.read(showArchivedProvider.notifier).state =
                                !showArchived,
                      ),
                    if (channels.isNotEmpty) ...[
                      const _SectionLabel('Departments & Channels'),
                      for (final c in channels)
                        _ConversationRow(
                          conversation: c,
                          selected: c.id == selectedId,
                          currentUserId: currentUserId,
                          onTap: () => onSelect(c.id),
                          onLongPress: () => showChatOptions(context, ref, c),
                        ),
                    ],
                    if (dms.isNotEmpty) ...[
                      const _SectionLabel('Direct Messages'),
                      for (final c in dms)
                        _ConversationRow(
                          conversation: c,
                          selected: c.id == selectedId,
                          currentUserId: currentUserId,
                          onTap: () => onSelect(c.id),
                          onLongPress: () => showChatOptions(context, ref, c),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.dns_rounded,
                  size: 13,
                  color: connected ? AppColor.success : AppColor.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Reverb Server',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const Spacer(),
                Text(
                  connected ? 'connected' : 'offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: connected ? AppColor.success : AppColor.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.selected,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
  });

  final Conversation conversation;
  final bool selected;
  final int currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isChannel = conversation.type != ConversationType.direct;
    final other = conversation.otherParticipant(currentUserId);
    final title = conversation.titleFor(currentUserId);
    final preview =
        conversation.latestMessage?.previewText ?? 'No messages yet';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? AppColor.brandSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (isChannel)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColor.brandSoft,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.tag_rounded,
                  size: 18,
                  color: AppColor.brand,
                ),
              )
            else if (other != null)
              AppAvatar.forUser(other, size: 36, showPresence: true)
            else
              const AppAvatar(label: '?', size: 36),
            Gap.md,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isChannel
                              ? '#${title.toLowerCase().replaceAll(' ', '-')}'
                              : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        Fmt.relative(conversation.lastMessageAt),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                  Gap.xs,
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                      ),
                      if (conversation.muted)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.volume_off_rounded,
                            size: 14,
                            color: AppColor.textMuted,
                          ),
                        ),
                      if (conversation.pinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: AppColor.textMuted,
                          ),
                        ),
                      if (conversation.unreadCount > 0)
                        CountBadge(
                          conversation.unreadCount,
                          color: AppColor.accent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right thread pane
// ---------------------------------------------------------------------------

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColor.canvas,
    child: const EmptyState(
      icon: Icons.forum_outlined,
      title: 'Select a conversation',
      message: 'Pick a channel or person on the left to start chatting.',
    ),
  );
}

class _ThreadPane extends ConsumerStatefulWidget {
  const _ThreadPane({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    this.onBack,
  });
  final int conversationId;
  final int currentUserId;

  /// Non-null only on narrow layouts, where the thread replaces (rather
  /// than sits beside) the conversation list.
  final VoidCallback? onBack;

  @override
  ConsumerState<_ThreadPane> createState() => _ThreadPaneState();
}

class _ThreadPaneState extends ConsumerState<_ThreadPane> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  Message? _replyTo;
  Message? _editing;
  bool _attaching = false;
  bool _showPanel = false;
  final _recorder = AudioRecorder();
  DateTime? _recordingSince;
  Timer? _recordTick;
  StreamSubscription<Amplitude>? _amplitudeSub;

  /// Recent mic levels (0..1), newest last: drives the live waveform.
  final List<double> _levels = [];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    _recordTick?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  bool get _recording => _recordingSince != null;

  int get _recordSeconds => _recordingSince == null
      ? 0
      : DateTime.now().difference(_recordingSince!).inSeconds;

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow microphone access to record voice notes'),
          ),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
    _inputFocus.unfocus();
    setState(() {
      _recordingSince = DateTime.now();
      _showPanel = false;
    });
    _recordTick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    _levels.clear();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((a) {
          // dBFS: about -60 is silence, 0 is as loud as it gets.
          final level = ((a.current + 60) / 60).clamp(0.05, 1.0);
          setState(() {
            _levels.add(level);
            if (_levels.length > 40) _levels.removeAt(0);
          });
        });
  }

  void _stopLevels() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _levels.clear();
  }

  Future<void> _cancelRecording() async {
    _recordTick?.cancel();
    _stopLevels();
    await _recorder.cancel();
    if (mounted) setState(() => _recordingSince = null);
  }

  Future<void> _sendRecording() async {
    final seconds = _recordSeconds;
    _recordTick?.cancel();
    _stopLevels();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recordingSince = null);
    if (path == null || seconds < 1) return; // too short to be useful
    setState(() => _attaching = true);
    await _thread.send(
      '',
      attachmentPath: path,
      attachmentName: 'Voice note.m4a',
      attachmentDurationSeconds: seconds,
      replyTo: _replyTo,
    );
    if (mounted) {
      setState(() {
        _attaching = false;
        _replyTo = null;
      });
    }
    _scrollToEnd();
  }

  MessageThreadController get _thread =>
      ref.read(messageThreadProvider(widget.conversationId).notifier);

  void _toggleEmojiPanel() {
    setState(() => _showPanel = !_showPanel);
    if (_showPanel) {
      _inputFocus.unfocus();
    } else {
      _inputFocus.requestFocus();
    }
  }

  /// Inserts at the cursor (or replaces the selection), like a keyboard.
  void _insertEmoji(String emoji) {
    final v = _controller.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, emoji);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + emoji.length),
    );
  }

  Future<void> _sendSticker(ChatSticker sticker) async {
    setState(() => _showPanel = false);
    await _thread.sendSticker(sticker.id);
    _scrollToEnd();
  }

  void _startEdit(Message m) {
    setState(() {
      _editing = m;
      _replyTo = null;
      _showPanel = false;
    });
    _controller.text = m.body ?? '';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _inputFocus.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _controller.clear();
  }

  Future<void> _copy(Message m) async {
    await Clipboard.setData(ClipboardData(text: m.body ?? ''));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message copied')));
    }
  }

  Future<void> _forward(Message m) async {
    final targets = await showForwardSheet(
      context,
      excludeConversationId: widget.conversationId,
    );
    if (targets == null || targets.isEmpty || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    var failed = 0;
    for (final id in targets) {
      try {
        await repo.forward(id, m.id);
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(conversationsProvider);
    final n = targets.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Forwarded to $n chat${n == 1 ? '' : 's'}'
              : 'Forwarded to ${n - failed} of $n chats',
        ),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final editing = _editing;
    if (editing != null) {
      final error = await _thread.editMessage(editing.id, text);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      _cancelEdit();
      return;
    }
    _thread.send(text, replyTo: _replyTo);
    _controller.clear();
    setState(() => _replyTo = null);
    _scrollToEnd();
  }

  Future<void> _attach({bool audioOnly = false}) async {
    final picked = await pickChatAttachment(context, audioOnly: audioOnly);
    if (picked == null || !mounted) return;
    setState(() => _attaching = true);
    await ref
        .read(messageThreadProvider(widget.conversationId).notifier)
        .send(
          '',
          attachmentPath: picked.path,
          attachmentName: picked.name,
          replyTo: _replyTo,
        );
    if (mounted) {
      setState(() {
        _attaching = false;
        _replyTo = null;
      });
    }
    _scrollToEnd();
  }

  void _reply(Message message) {
    setState(() => _replyTo = message);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageThreadProvider(widget.conversationId));
    final conversation = ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (list) =>
              list.where((c) => c.id == widget.conversationId).firstOrNull,
          orElse: () => null,
        );

    return Column(
      children: [
        _ThreadHeader(
          conversation: conversation,
          currentUserId: widget.currentUserId,
          onBack: widget.onBack,
          typingNames: state.typingNames,
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: AppColor.canvas,
            child: state.loading
                ? const LoadingBlock(height: 300)
                : state.messages.isEmpty
                ? const EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'Start the conversation',
                    message: 'Send the first message here.',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, i) {
                      final msg = state.messages[i];
                      final prev = i == 0 ? null : state.messages[i - 1];
                      final showDay =
                          prev == null ||
                          !_sameDay(prev.createdAt, msg.createdAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDay) _DayDivider(date: msg.createdAt),
                          _MessageBubble(
                            message: msg,
                            mine: msg.senderId == widget.currentUserId,
                            showAuthor:
                                (conversation?.type ??
                                        ConversationType.direct) !=
                                    ConversationType.direct &&
                                msg.senderId != widget.currentUserId &&
                                (prev == null || prev.senderId != msg.senderId),
                            onReply: () => _reply(msg),
                            onDeleteForMe: msg.id > 0
                                ? () => _thread.hideMessage(msg.id)
                                : null,
                            onCopy: msg.isSticker || (msg.body ?? '').isEmpty
                                ? null
                                : () => _copy(msg),
                            onForward: msg.pending ? null : () => _forward(msg),
                            onEdit: msg.canEdit(widget.currentUserId)
                                ? () => _startEdit(msg)
                                : null,
                            onDelete: msg.id > 0
                                ? () => ref
                                      .read(
                                        messageThreadProvider(
                                          widget.conversationId,
                                        ).notifier,
                                      )
                                      .deleteMessage(msg.id)
                                : null,
                            onReact: (emoji, mine) => ref
                                .read(
                                  messageThreadProvider(
                                    widget.conversationId,
                                  ).notifier,
                                )
                                .toggleReaction(msg.id, emoji, mine: mine),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        if (state.error != null)
          Container(
            width: double.infinity,
            color: AppColor.dangerSoft,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Text(
              state.error!,
              style: const TextStyle(fontSize: 11, color: AppColor.danger),
            ),
          ),
        _Composer(
          controller: _controller,
          focusNode: _inputFocus,
          onSend: _send,
          sending: state.sending || _attaching,
          replyTo: _replyTo,
          editing: _editing,
          onCancelEdit: _cancelEdit,
          emojiPanelOpen: _showPanel,
          onToggleEmoji: _toggleEmojiPanel,
          onCancelReply: () => setState(() => _replyTo = null),
          onAttach: () => _attach(),
          onAttachAudio: _startRecording,
          recordingSeconds: _recording ? _recordSeconds : null,
          recordingLevels: _levels,
          onCancelRecording: _cancelRecording,
          onSendRecording: _sendRecording,
          onTyping: () => ref
              .read(messageThreadProvider(widget.conversationId).notifier)
              .notifyTyping(),
        ),
        if (_showPanel)
          EmojiStickerPanel(onEmoji: _insertEmoji, onSticker: _sendSticker),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.conversation,
    required this.currentUserId,
    this.onBack,
    this.typingNames = const [],
  });
  final Conversation? conversation;
  final int currentUserId;
  final VoidCallback? onBack;
  final List<String> typingNames;

  String _typingText() => switch (typingNames.length) {
    0 => '',
    1 => '${typingNames.first} is typing...',
    2 => '${typingNames[0]} and ${typingNames[1]} are typing...',
    _ => 'Several people are typing...',
  };

  @override
  Widget build(BuildContext context) {
    final conv = conversation;
    final isChannel =
        (conv?.type ?? ConversationType.direct) != ConversationType.direct;
    final other = conv?.otherParticipant(currentUserId);
    final title = conv?.titleFor(currentUserId) ?? '...';
    final typingText = _typingText();

    return Container(
      height: AppLayout.topBarHeight,
      color: AppColor.surface,
      padding: EdgeInsets.only(left: onBack != null ? 4 : 20, right: 20),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
          if (isChannel)
            const Icon(Icons.tag_rounded, size: 20, color: AppColor.brand)
          else if (other != null)
            AppAvatar.forUser(other, size: 32, showPresence: true),
          Gap.md,
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isChannel
                      ? '#${title.toLowerCase().replaceAll(' ', '-')}'
                      : title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  typingText.isNotEmpty
                      ? typingText
                      : isChannel
                      ? '${conv?.participants.length ?? 0} members'
                      : (other?.isOnline ?? false)
                      ? 'online'
                      : 'offline',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: typingText.isNotEmpty ? AppColor.brand : null,
                    fontWeight: typingText.isNotEmpty ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (conv != null)
            IconButton(
              tooltip: 'Search messages',
              onPressed: () => showMessageSearch(context, conv.id),
              icon: const Icon(Icons.search_rounded, size: 20),
            ),
          if (isChannel)
            IconButton(
              tooltip: 'Group info',
              onPressed: conv == null
                  ? null
                  : () => showGroupInfoSheet(context, conv),
              icon: const Icon(Icons.info_outline_rounded, size: 19),
            ),
          if (conv != null)
            Consumer(
              builder: (context, ref, _) => IconButton(
                tooltip: 'Chat options',
                onPressed: () => showChatOptions(context, ref, conv),
                icon: const Icon(Icons.more_vert_rounded, size: 19),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pin / mute / archive for this user (long-press a chat, or ⋮ in it).
Future<void> showChatOptions(
  BuildContext context,
  WidgetRef ref,
  Conversation c,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              c.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            ),
            title: Text(c.pinned ? 'Unpin chat' : 'Pin chat'),
            onTap: () => Navigator.pop(sheet, 'pin'),
          ),
          ListTile(
            leading: Icon(
              c.muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            title: Text(
              c.muted ? 'Unmute notifications' : 'Mute notifications',
            ),
            onTap: () => Navigator.pop(sheet, 'mute'),
          ),
          ListTile(
            leading: Icon(
              c.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            ),
            title: Text(c.archived ? 'Unarchive chat' : 'Archive chat'),
            onTap: () => Navigator.pop(sheet, 'archive'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  final repo = ref.read(chatRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    switch (choice) {
      case 'pin':
        await repo.setPreferences(c.id, pinned: !c.pinned);
      case 'mute':
        await repo.setPreferences(c.id, muted: !c.muted);
      case 'archive':
        await repo.setPreferences(c.id, archived: !c.archived);
    }
    ref.invalidate(conversationsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (choice) {
          'pin' => c.pinned ? 'Chat unpinned' : 'Chat pinned',
          'mute' => c.muted ? 'Notifications on' : 'Chat muted',
          _ => c.archived ? 'Chat unarchived' : 'Chat archived',
        }),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// Search text messages in one chat.
Future<void> showMessageSearch(BuildContext context, int conversationId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MessageSearchSheet(conversationId: conversationId),
  );
}

class _MessageSearchSheet extends ConsumerStatefulWidget {
  const _MessageSearchSheet({required this.conversationId});
  final int conversationId;

  @override
  ConsumerState<_MessageSearchSheet> createState() =>
      _MessageSearchSheetState();
}

class _MessageSearchSheetState extends ConsumerState<_MessageSearchSheet> {
  Timer? _debounce;
  List<Message>? _results;
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v.trim()));
  }

  Future<void> _run(String q) async {
    setState(() => _query = q);
    if (q.length < 2) return setState(() => _results = null);
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(chatRepositoryProvider)
          .searchMessages(widget.conversationId, q);
      if (mounted && q == _query) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: _results == null
                ? Center(
                    child: Text('Type at least 2 letters', style: t.bodySmall),
                  )
                : _results!.isEmpty
                ? Center(child: Text('No messages found', style: t.bodySmall))
                : ListView.separated(
                    itemCount: _results!.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = _results![i];
                      return ListTile(
                        title: Text(
                          m.body ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${m.sender?.name ?? ''} • '
                          '${Fmt.shortDate(m.createdAt)} ${Fmt.time(m.createdAt)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColor.border),
        ),
        child: Text(
          Fmt.dayHeading(date),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showAuthor,
    this.onReply,
    this.onDelete,
    this.onReact,
    this.onCopy,
    this.onForward,
    this.onEdit,
    this.onDeleteForMe,
  });
  final VoidCallback? onDeleteForMe;
  final Message message;
  final bool mine;
  final bool showAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(String emoji, bool mine)? onReact;

  void _openMenu(BuildContext context) {
    if (message.deleted) {
      if (onDeleteForMe == null) return;
      showModalBottomSheet<void>(
        context: context,
        builder: (sheet) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Delete for me'),
            onTap: () {
              Navigator.of(sheet).pop();
              onDeleteForMe!.call();
            },
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          // Material (not a coloured Container) so the ListTiles' ink shows.
          child: Material(
            color: AppColor.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final emoji in _quickReactions)
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(context).pop();
                            final already = message.reactions
                                .where((r) => r.mine)
                                .any((r) => r.emoji == emoji);
                            onReact?.call(emoji, already);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onReply?.call();
                  },
                ),
                if (onCopy != null)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded),
                    title: const Text('Copy'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onCopy!.call();
                    },
                  ),
                if (onForward != null)
                  ListTile(
                    leading: const Icon(Icons.shortcut_rounded),
                    title: const Text('Forward'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onForward!.call();
                    },
                  ),
                if (onEdit != null)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onEdit!.call();
                    },
                  ),
                if (onDeleteForMe != null)
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: const Text('Delete for me'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onDeleteForMe!.call();
                    },
                  ),
                if (mine && onDelete != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColor.danger,
                    ),
                    title: const Text(
                      'Delete for everyone',
                      style: TextStyle(color: AppColor.danger),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onDelete!.call();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppColor.brand : AppColor.surface;
    final fg = mine ? Colors.white : AppColor.textPrimary;

    if (message.deleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onLongPress: () => _openMenu(context),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColor.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    size: 14,
                    color: AppColor.textMuted,
                  ),
                  Gap.xs,
                  Text(
                    'This message was deleted',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showAuthor && message.sender != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                message.sender!.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (message.isSticker)
            GestureDetector(
              onLongPress: () => _openMenu(context),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.forwarded)
                    const _ForwardedLabel(color: AppColor.textMuted),
                  StickerView(stickerId: message.body),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      Fmt.time(message.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColor.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onLongPress: () => _openMenu(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(mine ? 12 : 3),
                      bottomRight: Radius.circular(mine ? 3 : 12),
                    ),
                    border: mine ? null : Border.all(color: AppColor.border),
                    boxShadow: mine ? null : AppShadow.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.forwarded)
                        _ForwardedLabel(
                          color: mine ? Colors.white70 : AppColor.textMuted,
                        ),
                      if (message.replyTo != null)
                        _ReplyPreview(reply: message.replyTo!, mine: mine),
                      for (final a in message.attachments) ...[
                        _Attachment(attachment: a, mine: mine),
                        const SizedBox(height: 6),
                      ],
                      if (message.body != null && message.body!.isNotEmpty)
                        Text(
                          message.body!,
                          style: TextStyle(
                            color: fg,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.editedAt != null)
                            Text(
                              'Edited · ',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: mine
                                    ? Colors.white70
                                    : AppColor.textMuted,
                              ),
                            ),
                          Text(
                            Fmt.time(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: mine ? Colors.white70 : AppColor.textMuted,
                            ),
                          ),
                          if (mine) ...[
                            const SizedBox(width: 3),
                            Icon(
                              message.pending
                                  ? Icons.schedule_rounded
                                  : message.readBy.length > 1
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 13,
                              color: message.readBy.length > 1
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (message.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final r in message.reactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onReact?.call(r.emoji, r.mine),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: r.mine
                              ? AppColor.brandSoft
                              : AppColor.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                          border: r.mine
                              ? Border.all(color: AppColor.brand)
                              : null,
                        ),
                        child: Text(
                          '${r.emoji} ${r.count}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ForwardedLabel extends StatelessWidget {
  const _ForwardedLabel({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shortcut_rounded, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          'Forwarded',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Pick one or more chats to forward a message to.
Future<List<int>?> showForwardSheet(
  BuildContext context, {
  required int excludeConversationId,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ForwardSheet(excludeConversationId: excludeConversationId),
  );
}

class _ForwardSheet extends ConsumerStatefulWidget {
  const _ForwardSheet({required this.excludeConversationId});
  final int excludeConversationId;

  @override
  ConsumerState<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<_ForwardSheet> {
  final _selected = <int>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final conversations =
        ref.watch(conversationsProvider).valueOrNull ?? const [];
    final options = conversations
        .where((c) => c.id != widget.excludeConversationId)
        .where(
          (c) => c
              .titleFor(me?.id ?? 0)
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Forward to…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    _selected.isEmpty ? 'Send' : 'Send (${_selected.length})',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: options.isEmpty
                ? const Center(child: Text('No other chats to forward to.'))
                : ListView(
                    children: [
                      for (final c in options)
                        CheckboxListTile(
                          value: _selected.contains(c.id),
                          onChanged: (v) => setState(
                            () => v == true
                                ? _selected.add(c.id)
                                : _selected.remove(c.id),
                          ),
                          title: Text(c.titleFor(me?.id ?? 0)),
                          secondary: Icon(
                            c.type == ConversationType.direct
                                ? Icons.person_outline_rounded
                                : Icons.groups_outlined,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.reply, required this.mine});
  final MessageReplyPreview reply;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final barColor = mine ? Colors.white70 : AppColor.brand;
    final textColor = mine ? Colors.white : AppColor.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.12)
            : AppColor.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: barColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderName ?? 'Unknown',
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            reply.deleted ? 'Message deleted' : (reply.body ?? 'Attachment'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontStyle: reply.deleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({required this.attachment, required this.mine});
  final MessageAttachment attachment;
  final bool mine;

  Uri get _absoluteUrl => Uri.parse(
    attachment.url.startsWith('http')
        ? attachment.url
        : '${Env.apiBaseUrl}${attachment.url}',
  );

  Future<void> _open() =>
      launchUrl(_absoluteUrl, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return GestureDetector(
        onTap: () => _viewImage(context),
        child: ClipRRect(
          borderRadius: AppRadius.md,
          child: Image.network(
            _absoluteUrl.toString(),
            width: 260,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fileCard(context),
          ),
        ),
      );
    }
    if (attachment.isVideo) {
      return GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _VideoViewer(url: _absoluteUrl.toString()),
          ),
        ),
        child: Container(
          width: 240,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: AppRadius.md,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                size: 52,
                color: Colors.white,
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Row(
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Fmt.fileSize(attachment.fileSize),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (attachment.isVoice) {
      return _VoiceNote(
        url: _absoluteUrl.toString(),
        attachment: attachment,
        mine: mine,
      );
    }
    return GestureDetector(onTap: _open, child: _fileCard(context));
  }

  /// Full screen, pinch to zoom, like WhatsApp; files still open outside.
  void _viewImage(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Open in another app',
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: _open,
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(_absoluteUrl.toString()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fileCard(BuildContext context) {
    final onColor = mine ? Colors.white : AppColor.textPrimary;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: 0.14)
            : AppColor.surfaceMuted,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Icon(
            attachment.isVideo
                ? Icons.videocam_outlined
                : Icons.insert_drive_file_outlined,
            color: onColor,
            size: 20,
          ),
          Gap.sm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName ?? 'file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  Fmt.fileSize(attachment.fileSize),
                  style: TextStyle(
                    color: mine ? Colors.white70 : AppColor.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            attachment.isVideo
                ? Icons.play_circle_outline_rounded
                : Icons.download_rounded,
            color: onColor,
            size: 16,
          ),
        ],
      ),
    );
  }
}

/// Full-screen in-app video player: tap to play/pause, seekable bar.
class _VideoViewer extends StatefulWidget {
  const _VideoViewer({required this.url});
  final String url;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
  );
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.initialize().then(
      (_) {
        if (mounted) {
          setState(() {});
          _c.play();
        }
      },
      onError: (_) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _failed
          ? const Center(
              child: Text(
                'Could not play this video',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : !v.isInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : GestureDetector(
              onTap: () => v.isPlaying ? _c.pause() : _c.play(),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: v.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_c),
                            if (!v.isPlaying)
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                size: 64,
                                color: Colors.white70,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            Fmt.duration(v.position.inSeconds),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _c,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              colors: const VideoProgressColors(
                                playedColor: Colors.white,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                          ),
                          Text(
                            Fmt.duration(v.duration.inSeconds),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// In-chat voice note player: play/pause, seekable progress and time,
/// like WhatsApp. Only one note plays at a time.
class _VoiceNote extends StatefulWidget {
  const _VoiceNote({
    required this.url,
    required this.attachment,
    required this.mine,
  });
  final String url;
  final MessageAttachment attachment;
  final bool mine;

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  static _VoiceNoteState? _playing;

  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final known = widget.attachment.durationSeconds;
    if (known != null && known > 0) _duration = Duration(seconds: known);
    _subs
      ..add(
        _player.onPlayerStateChanged.listen((s) {
          if (mounted) setState(() => _state = s);
        }),
      )
      ..add(
        _player.onPositionChanged.listen((p) {
          if (mounted) setState(() => _position = p);
        }),
      )
      ..add(
        _player.onDurationChanged.listen((d) {
          if (mounted && d > Duration.zero) setState(() => _duration = d);
        }),
      )
      ..add(
        _player.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _position = Duration.zero);
        }),
      );
  }

  @override
  void dispose() {
    if (identical(_playing, this)) _playing = null;
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (!identical(_playing, this)) await _playing?._player.pause();
    _playing = this;
    if (_state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    setState(() => _loading = true);
    try {
      await _player.play(UrlSource(widget.url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play voice note')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final onColor = mine ? Colors.white : AppColor.brand;
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final playing = _state == PlayerState.playing;
    final shown = playing || _position > Duration.zero ? _position : total;

    return SizedBox(
      width: 240,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onColor,
                    ),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 32,
                    tooltip: playing ? 'Pause' : 'Play',
                    onPressed: _toggle,
                    icon: Icon(
                      playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: onColor,
                    ),
                  ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: onColor,
                inactiveTrackColor: onColor.withValues(alpha: 0.3),
                thumbColor: onColor,
              ),
              child: Slider(
                value: progress,
                onChanged: total == Duration.zero
                    ? null
                    : (v) => _player.seek(
                        Duration(
                          milliseconds: (v * total.inMilliseconds).round(),
                        ),
                      ),
              ),
            ),
          ),
          Text(
            Fmt.duration(shown.inSeconds),
            style: TextStyle(
              fontSize: 11,
              color: mine ? Colors.white70 : AppColor.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bars that rise and fall with the microphone while recording, newest
/// on the right, so it's obvious the voice is being picked up.
class _LiveWaveform extends StatelessWidget {
  const _LiveWaveform({required this.levels});
  final List<double> levels;

  static const _bars = 40;

  @override
  Widget build(BuildContext context) {
    final padded = [
      ...List<double>.filled((_bars - levels.length).clamp(0, _bars), 0.05),
      ...levels.length > _bars ? levels.sublist(levels.length - _bars) : levels,
    ];
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final l in padded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 3,
              height: 4 + l * 28,
              decoration: BoxDecoration(
                color: AppColor.brand.withValues(alpha: 0.35 + l * 0.65),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
    this.replyTo,
    this.editing,
    this.onCancelEdit,
    this.emojiPanelOpen = false,
    this.onToggleEmoji,
    this.onCancelReply,
    this.onAttach,
    this.onAttachAudio,
    this.onTyping,
    this.recordingSeconds,
    this.recordingLevels = const [],
    this.onCancelRecording,
    this.onSendRecording,
  });

  /// Non-null while a voice note is being recorded.
  final int? recordingSeconds;
  final List<double> recordingLevels;
  final VoidCallback? onCancelRecording;
  final VoidCallback? onSendRecording;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool sending;
  final Message? replyTo;
  final Message? editing;
  final VoidCallback? onCancelEdit;
  final bool emojiPanelOpen;
  final VoidCallback? onToggleEmoji;
  final VoidCallback? onCancelReply;
  final VoidCallback? onAttach;
  final VoidCallback? onAttachAudio;
  final VoidCallback? onTyping;

  /// Desktop/web: Enter sends, Shift+Enter breaks the line. Phones keep
  /// their keyboard's own send/newline keys.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final enter =
        e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!enter || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (!sending) onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Container(
      color: AppColor.surface,
      padding: EdgeInsets.fromLTRB(narrow ? 8 : 16, 10, narrow ? 8 : 16, 12),
      child: Column(
        children: [
          if (editing != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColor.accentSoft,
                borderRadius: AppRadius.md,
                border: const Border(
                  left: BorderSide(color: AppColor.accent, width: 3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, size: 16),
                  Gap.sm,
                  Expanded(
                    child: Text(
                      'Editing message',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 16,
                    tooltip: 'Cancel edit',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onCancelEdit,
                  ),
                ],
              ),
            ),
          if (replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColor.surfaceMuted,
                borderRadius: AppRadius.md,
                border: const Border(
                  left: BorderSide(color: AppColor.brand, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${replyTo!.sender?.name ?? 'message'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                        ),
                        Text(
                          replyTo!.deleted
                              ? 'Message deleted'
                              : (replyTo!.body ?? 'Attachment'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 16,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onCancelReply,
                  ),
                ],
              ),
            ),
          if (recordingSeconds != null)
            Row(
              children: [
                IconButton(
                  tooltip: 'Discard',
                  onPressed: onCancelRecording,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColor.danger,
                  ),
                ),
                const Icon(
                  Icons.fiber_manual_record_rounded,
                  color: AppColor.danger,
                  size: 14,
                ),
                Gap.sm,
                Text(
                  Fmt.duration(recordingSeconds),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Gap.sm,
                Expanded(child: _LiveWaveform(levels: recordingLevels)),
                Gap.sm,
                FilledButton(
                  onPressed: onSendRecording,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            )
          else
            Row(
              children: [
                IconButton(
                  tooltip: emojiPanelOpen ? 'Keyboard' : 'Emoji & stickers',
                  onPressed: onToggleEmoji,
                  icon: Icon(
                    emojiPanelOpen
                        ? Icons.keyboard_rounded
                        : Icons.emoji_emotions_outlined,
                    size: 22,
                  ),
                ),
                if (editing == null) ...[
                  IconButton(
                    tooltip: 'Attach',
                    onPressed: sending ? null : onAttach,
                    icon: const Icon(Icons.attach_file_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Record voice note',
                    onPressed: sending ? null : onAttachAudio,
                    icon: const Icon(Icons.mic_none_rounded, size: 20),
                  ),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode..onKeyEvent = narrow ? null : _onKey,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    onChanged: (v) {
                      if (v.trim().isNotEmpty) onTyping?.call();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      fillColor: AppColor.surfaceMuted,
                    ),
                  ),
                ),
                Gap.sm,
                FilledButton(
                  onPressed: sending ? null : onSend,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    editing != null ? Icons.check_rounded : Icons.send_rounded,
                    size: 18,
                  ),
                ),
              ],
            ),
          if (!narrow)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Enter to send · Shift + Enter for a new line',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
              ),
            ),
        ],
      ),
    );
  }
}
