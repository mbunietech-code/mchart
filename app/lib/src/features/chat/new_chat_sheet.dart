import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primitives.dart';
import '../auth/auth_controller.dart';
import '../directory/directory_repository.dart';
import 'chat_repository.dart';

/// Opens the "start a new conversation" flow: search colleagues, pick one
/// for a direct message or several for a group, then create it. Returns the
/// new/reused [Conversation], or null if the user backed out.
Future<Conversation?> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet<Conversation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NewChatSheet(),
  );
}

class _NewChatSheet extends ConsumerStatefulWidget {
  const _NewChatSheet();

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  final _search = TextEditingController();
  final _groupName = TextEditingController();
  final _selected = <int, User>{};
  Timer? _debounce;
  String _query = '';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v);
    });
  }

  void _toggle(User user) {
    setState(() {
      if (_selected.containsKey(user.id)) {
        _selected.remove(user.id);
      } else {
        _selected[user.id] = user;
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    if (_selected.length > 1 && _groupName.text.trim().isEmpty) {
      setState(() => _error = 'Give the group a name.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(chatRepositoryProvider);
      final conversation = _selected.length == 1
          ? await repo.createDirect(_selected.values.first.id)
          : await repo.createGroup(
              _groupName.text.trim(),
              _selected.keys.toList(),
            );
      ref.invalidate(conversationsProvider);
      if (mounted) Navigator.of(context).pop(conversation);
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Could not start the conversation. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
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
                          'New conversation',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search colleagues by name or email',
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      fillColor: AppColor.surfaceMuted,
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final u in _selected.values)
                          Chip(
                            label: Text(u.name),
                            onDeleted: () => _toggle(u),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                if (_selected.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _groupName,
                      decoration: const InputDecoration(
                        hintText: 'Group name',
                        fillColor: AppColor.surfaceMuted,
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColor.danger,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: _UserResults(
                    query: _query,
                    excludeUserId: me?.id,
                    selectedIds: _selected.keys.toSet(),
                    onTap: _toggle,
                    scrollController: scrollController,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _selected.isEmpty || _submitting
                            ? null
                            : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _selected.length > 1
                                    ? 'Create group'
                                    : 'Start chat',
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserResults extends ConsumerWidget {
  const _UserResults({
    required this.query,
    required this.excludeUserId,
    required this.selectedIds,
    required this.onTap,
    required this.scrollController,
  });

  final String query;
  final int? excludeUserId;
  final Set<int> selectedIds;
  final ValueChanged<User> onTap;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(_newChatUserSearchProvider(query));

    return result.when(
      loading: () => const LoadingBlock(height: 200),
      error: (e, _) => ErrorBlock(
        message: '$e',
        onRetry: () => ref.invalidate(_newChatUserSearchProvider(query)),
      ),
      data: (users) {
        final list = users.where((u) => u.id != excludeUserId).toList();
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No one found',
          );
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: list.length,
          itemBuilder: (context, i) {
            final u = list[i];
            final selected = selectedIds.contains(u.id);
            return ListTile(
              leading: AppAvatar.forUser(u, size: 36),
              title: Text(u.name),
              subtitle: Text(
                u.department?.name ?? u.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Checkbox(value: selected, onChanged: (_) => onTap(u)),
              onTap: () => onTap(u),
            );
          },
        );
      },
    );
  }
}

final _newChatUserSearchProvider = FutureProvider.autoDispose
    .family<List<User>, String>((ref, query) async {
      final repo = ref.watch(directoryRepositoryProvider);
      final page = await repo.users(
        search: query,
        status: 'active',
        perPage: 50,
      );
      return page.items;
    });
