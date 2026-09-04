import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'chat_repository.dart';
import 'message_thread_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final me = ref.watch(currentUserProvider)!;

    return Row(
      children: [
        SizedBox(
          width: AppLayout.listPaneWidth,
          child: _ListPane(
            conversations: conversations,
            selectedId: _selected,
            search: _search,
            currentUserId: me.id,
            onSearch: (v) => setState(() => _search = v),
            onSelect: (id) {
              setState(() => _selected = id);
              context.go('/chats?c=$id');
            },
          ),
        ),
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
  });

  final AsyncValue<List<Conversation>> conversations;
  final int? selectedId;
  final String search;
  final int currentUserId;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(realtimeConnectedProvider).maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );

    return Container(
      color: AppColor.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              onChanged: onSearch,
              decoration: const InputDecoration(
                hintText: 'Search chats and channels',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                fillColor: AppColor.surfaceMuted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: conversations.maybeWhen(
                    data: (list) => Text('ALL CHATS ${list.length}',
                        style: Theme.of(context).textTheme.labelSmall),
                    orElse: () => Text('CHATS',
                        style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
                LivePill(online: connected, onlineLabel: 'Reverb Active', offlineLabel: 'Offline'),
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
                        .where((c) => c
                            .titleFor(currentUserId)
                            .toLowerCase()
                            .contains(search.toLowerCase()))
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
                Icon(Icons.dns_rounded,
                    size: 13, color: connected ? AppColor.success : AppColor.textMuted),
                const SizedBox(width: 6),
                Text('Reverb Server',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                const Spacer(),
                Text(connected ? 'connected' : 'offline',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: connected ? AppColor.success : AppColor.textMuted)),
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
        child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
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
    final preview = conversation.latestMessage?.body ??
        (conversation.latestMessage != null ? '[attachment]' : 'No messages yet');

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
                    color: AppColor.brandSoft, borderRadius: AppRadius.md),
                child: const Icon(Icons.tag_rounded, size: 18, color: AppColor.brand),
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
                          isChannel ? '#${title.toLowerCase().replaceAll(' ', '-')}' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        Fmt.relative(conversation.lastMessageAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        CountBadge(conversation.unreadCount, color: AppColor.accent),
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
  const _ThreadPane({super.key, required this.conversationId, required this.currentUserId});
  final int conversationId;
  final int currentUserId;

  @override
  ConsumerState<_ThreadPane> createState() => _ThreadPaneState();
}

class _ThreadPaneState extends ConsumerState<_ThreadPane> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(messageThreadProvider(widget.conversationId).notifier).send(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageThreadProvider(widget.conversationId));
    final conversation = ref.watch(conversationsProvider).maybeWhen(
          data: (list) =>
              list.where((c) => c.id == widget.conversationId).firstOrNull,
          orElse: () => null,
        );

    return Column(
      children: [
        _ThreadHeader(conversation: conversation, currentUserId: widget.currentUserId),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) {
                          final msg = state.messages[i];
                          final prev = i == 0 ? null : state.messages[i - 1];
                          final showDay = prev == null ||
                              !_sameDay(prev.createdAt, msg.createdAt);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDay) _DayDivider(date: msg.createdAt),
                              _MessageBubble(
                                message: msg,
                                mine: msg.senderId == widget.currentUserId,
                                showAuthor: (conversation?.type ?? ConversationType.direct) !=
                                        ConversationType.direct &&
                                    msg.senderId != widget.currentUserId &&
                                    (prev == null || prev.senderId != msg.senderId),
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
            child: Text(state.error!,
                style: const TextStyle(fontSize: 11, color: AppColor.danger)),
          ),
        _Composer(controller: _controller, onSend: _send, sending: state.sending),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.conversation, required this.currentUserId});
  final Conversation? conversation;
  final int currentUserId;

  @override
  Widget build(BuildContext context) {
    final isChannel =
        (conversation?.type ?? ConversationType.direct) != ConversationType.direct;
    final other = conversation?.otherParticipant(currentUserId);
    final title = conversation?.titleFor(currentUserId) ?? '...';

    return Container(
      height: AppLayout.topBarHeight,
      color: AppColor.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
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
                  isChannel
                      ? '${conversation?.participants.length ?? 0} members'
                      : (other?.isOnline ?? false)
                          ? 'online'
                          : 'offline',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded, size: 19)),
          IconButton(
              onPressed: () {}, icon: const Icon(Icons.perm_media_outlined, size: 19)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded, size: 19)),
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
            child: Text(Fmt.dayHeading(date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          ),
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine, required this.showAuthor});
  final Message message;
  final bool mine;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppColor.brand : AppColor.surface;
    final fg = mine ? Colors.white : AppColor.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showAuthor && message.sender != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(message.sender!.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                  for (final a in message.attachments) ...[
                    _Attachment(attachment: a, mine: mine),
                    const SizedBox(height: 6),
                  ],
                  if (message.body != null && message.body!.isNotEmpty)
                    Text(message.body!, style: TextStyle(color: fg, fontSize: 13.5, height: 1.4)),
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
                          color: message.readBy.length > 1 ? Colors.white : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: AppRadius.md,
        child: Image.network(
          attachment.url,
          width: 260,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fileCard(context),
        ),
      );
    }
    if (attachment.isVoice) return _VoiceNote(attachment: attachment, mine: mine);
    return _fileCard(context);
  }

  Widget _fileCard(BuildContext context) {
    final onColor = mine ? Colors.white : AppColor.textPrimary;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: mine ? Colors.white.withValues(alpha: 0.14) : AppColor.surfaceMuted,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined, color: onColor, size: 20),
          Gap.sm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attachment.fileName ?? 'faili',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: onColor, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(Fmt.fileSize(attachment.fileSize),
                    style: TextStyle(
                        color: mine ? Colors.white70 : AppColor.textMuted, fontSize: 10.5)),
              ],
            ),
          ),
          Icon(Icons.download_rounded, color: onColor, size: 16),
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
                      color: (mine ? Colors.white : AppColor.brand)
                          .withValues(alpha: i.isEven ? 0.9 : 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Gap.sm,
          Text(Fmt.duration(attachment.durationSeconds ?? 0),
              style: TextStyle(
                  fontSize: 11,
                  color: mine ? Colors.white70 : AppColor.textSecondary)),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.sending});
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.attach_file_rounded, size: 20)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.mic_none_rounded, size: 20)),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
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
            child: Row(
              children: [
                Text('Enter to send · Shift + Enter for a new line',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                const Spacer(),
                Text('Reverb E2E',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10.5, color: AppColor.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
