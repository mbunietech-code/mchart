import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/pills.dart';
import '../auth/auth_controller.dart';
import '../directory/directory_repository.dart';
import 'chat_repository.dart';

/// Group admin controls: rename, add/remove members, leave. Opened from the
/// thread header's info button on a group/channel conversation.
void showGroupInfoSheet(BuildContext context, Conversation conversation) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupInfoSheet(conversation: conversation),
  );
}

class _GroupInfoSheet extends ConsumerStatefulWidget {
  const _GroupInfoSheet({required this.conversation});
  final Conversation conversation;

  @override
  ConsumerState<_GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends ConsumerState<_GroupInfoSheet> {
  late Conversation _conversation = widget.conversation;
  bool _busy = false;

  Future<void> _rename() async {
    final controller = TextEditingController(text: _conversation.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(chatRepositoryProvider)
          .renameGroup(_conversation.id, name);
      ref.invalidate(conversationsProvider);
      setState(() {
        _conversation = updated;
        _busy = false;
      });
    } catch (_) {
      setState(() => _busy = false);
    }
  }

  Future<void> _addMembers() async {
    final added = await showModalBottomSheet<List<User>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMembersSheet(
        existingIds: _conversation.participants.map((p) => p.id).toSet(),
      ),
    );
    if (added == null || added.isEmpty) return;
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(chatRepositoryProvider)
          .addParticipants(_conversation.id, added.map((u) => u.id).toList());
      ref.invalidate(conversationsProvider);
      setState(() {
        _conversation = updated;
        _busy = false;
      });
    } catch (_) {
      setState(() => _busy = false);
    }
  }

  Future<void> _remove(User user) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .removeParticipant(_conversation.id, user.id);
      ref.invalidate(conversationsProvider);
      setState(() {
        _conversation = Conversation(
          id: _conversation.id,
          type: _conversation.type,
          name: _conversation.name,
          departmentId: _conversation.departmentId,
          createdBy: _conversation.createdBy,
          lastMessageAt: _conversation.lastMessageAt,
          unreadCount: _conversation.unreadCount,
          participants: _conversation.participants
              .where((p) => p.id != user.id)
              .toList(),
          participantRoles: _conversation.participantRoles,
        );
        _busy = false;
      });
    } catch (_) {
      setState(() => _busy = false);
    }
  }

  Future<void> _leave(int myId) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .removeParticipant(_conversation.id, myId);
      ref.invalidate(conversationsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final amAdmin = me != null && _conversation.isAdmin(me.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColor.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _conversation.name ?? 'Group info',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (amAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _busy ? null : _rename,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '${_conversation.participants.length} members',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (amAdmin)
                      TextButton.icon(
                        onPressed: _busy ? null : _addMembers,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 16,
                        ),
                        label: const Text('Add'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    for (final p in _conversation.participants)
                      ListTile(
                        leading: AppAvatar.forUser(p, size: 36),
                        title: Text(p.name),
                        subtitle: Text(p.email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_conversation.isAdmin(p.id))
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: StatusPill(
                                  'Admin',
                                  color: AppColor.brand,
                                  dense: true,
                                ),
                              ),
                            if (amAdmin && me != null && p.id != me.id)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 18,
                                ),
                                onPressed: _busy ? null : () => _remove(p),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy || me == null
                          ? null
                          : () => _leave(me.id),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColor.danger,
                      ),
                      label: const Text(
                        'Leave group',
                        style: TextStyle(color: AppColor.danger),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddMembersSheet extends ConsumerStatefulWidget {
  const _AddMembersSheet({required this.existingIds});
  final Set<int> existingIds;

  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final _selected = <int, User>{};

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColor.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(child: Text('Add members')),
                    FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(_selected.values.toList()),
                      child: Text('Add (${_selected.length})'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: users.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (page) {
                    final candidates = page.items
                        .where((u) => !widget.existingIds.contains(u.id))
                        .toList();
                    return ListView(
                      controller: scrollController,
                      children: [
                        for (final u in candidates)
                          CheckboxListTile(
                            value: _selected.containsKey(u.id),
                            onChanged: (v) => setState(() {
                              if (v ?? false) {
                                _selected[u.id] = u;
                              } else {
                                _selected.remove(u.id);
                              }
                            }),
                            secondary: AppAvatar.forUser(u, size: 34),
                            title: Text(u.name),
                            subtitle: Text(u.email),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
