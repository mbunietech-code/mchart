import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
                final channels = filtered
                    .where((c) => c.type != ConversationType.direct)
                    .toList();
                final dms = filtered
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
                    if (channels.isNotEmpty) ...[
                      const _SectionLabel('Departments & Channels'),
                      for (final c in channels)
                        _ConversationRow(
                          conversation: c,
                          selected: c.id == selectedId,
                          currentUserId: currentUserId,
                          onTap: () => onSelect(c.id),
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
  });

  final Conversation conversation;
  final bool selected;
  final int currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isChannel = conversation.type != ConversationType.direct;
    final other = conversation.otherParticipant(currentUserId);
    final title = conversation.titleFor(currentUserId);
    final preview =
        conversation.latestMessage?.body ??
        (conversation.latestMessage != null
            ? '[attachment]'
            : 'No messages yet');

    return InkWell(
      onTap: onTap,
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
  Message? _replyTo;
  bool _attaching = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
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

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref
        .read(messageThreadProvider(widget.conversationId).notifier)
        .send(text, replyTo: _replyTo);
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
          onSend: _send,
          sending: state.sending || _attaching,
          replyTo: _replyTo,
          onCancelReply: () => setState(() => _replyTo = null),
          onAttach: () => _attach(),
          onAttachAudio: () => _attach(audioOnly: true),
          onTyping: () => ref
              .read(messageThreadProvider(widget.conversationId).notifier)
              .notifyTyping(),
        ),
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
          if (isChannel)
            IconButton(
              tooltip: 'Group info',
              onPressed: conv == null
                  ? null
                  : () => showGroupInfoSheet(context, conv),
              icon: const Icon(Icons.info_outline_rounded, size: 19),
            )
          else
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert_rounded, size: 19),
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
  });
  final Message message;
  final bool mine;
  final bool showAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final void Function(String emoji, bool mine)? onReact;

  void _openMenu(BuildContext context) {
    if (message.deleted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColor.surface,
            borderRadius: BorderRadius.circular(16),
          ),
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
              if (mine && onDelete != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColor.danger,
                  ),
                  title: const Text(
                    'Delete',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppColor.brand : AppColor.surface;
    final fg = mine ? Colors.white : AppColor.textPrimary;

    if (message.deleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
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
        onTap: _open,
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
    if (attachment.isVoice) {
      return GestureDetector(
        onTap: _open,
        child: _VoiceNote(attachment: attachment, mine: mine),
      );
    }
    return GestureDetector(onTap: _open, child: _fileCard(context));
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

class _VoiceNote extends StatelessWidget {
  const _VoiceNote({required this.attachment, required this.mine});
  final MessageAttachment attachment;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final onColor = mine ? Colors.white : AppColor.brand;
    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.play_circle_fill_rounded, size: 30, color: onColor),
          Gap.sm,
          Expanded(
            child: SizedBox(
              height: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  22,
                  (i) => Container(
                    width: 2.5,
                    height: (i % 5 + 1) * 3.5 + 4,
                    decoration: BoxDecoration(
                      color: (mine ? Colors.white : AppColor.brand).withValues(
                        alpha: i.isEven ? 0.9 : 0.45,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Gap.sm,
          Text(
            Fmt.duration(attachment.durationSeconds ?? 0),
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.sending,
    this.replyTo,
    this.onCancelReply,
    this.onAttach,
    this.onAttachAudio,
    this.onTyping,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final Message? replyTo;
  final VoidCallback? onCancelReply;
  final VoidCallback? onAttach;
  final VoidCallback? onAttachAudio;
  final VoidCallback? onTyping;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
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
          Row(
            children: [
              IconButton(
                onPressed: sending ? null : onAttach,
                icon: const Icon(Icons.attach_file_rounded, size: 20),
              ),
              IconButton(
                onPressed: sending ? null : onAttachAudio,
                icon: const Icon(Icons.mic_none_rounded, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
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
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
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
