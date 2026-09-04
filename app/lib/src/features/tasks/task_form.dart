import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/enums.dart';
import '../../models/task.dart';
import '../../theme/app_spacing.dart';
import '../directory/directory_repository.dart';
import 'task_repository.dart';

Future<void> showTaskForm(BuildContext context, WidgetRef ref, {Task? task}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _TaskForm(task: task),
      ),
    ),
  );
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({this.task});
  final Task? task;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(text: widget.task?.description);
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.medium;
  late DateTime? _deadline = widget.task?.deadline;
  late int? _assigneeId = widget.task?.assignee?.id;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _assigneeId == null) {
      setState(() => _error = _assigneeId == null ? 'Chagua mfanyakazi wa kupewa kazi.' : null);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(taskRepositoryProvider);
    final body = {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'priority': _priority.name,
      'assigned_to': _assigneeId,
      if (_deadline != null) 'deadline': _deadline!.toIso8601String(),
    };
    try {
      if (_isEdit) {
        await repo.update(widget.task!.id, body);
        ref.invalidate(taskDetailProvider(widget.task!.id));
      } else {
        await repo.create(body);
      }
      ref.invalidate(taskBoardProvider);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Hariri Kazi' : 'Kazi Mpya',
                style: Theme.of(context).textTheme.titleLarge),
            Gap.lg,
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Kichwa cha kazi'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Weka kichwa' : null,
            ),
            Gap.md,
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Maelezo (hiari)'),
            ),
            Gap.md,
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TaskPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Kipaumbele'),
                    items: [
                      for (final p in TaskPriority.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? TaskPriority.medium),
                  ),
                ),
                Gap.md,
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline ?? DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _deadline = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Tarehe ya mwisho'),
                      child: Text(
                        _deadline == null
                            ? 'Hakuna'
                            : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Gap.md,
            users.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (page) => DropdownButtonFormField<int>(
                initialValue: _assigneeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mpewe kazi'),
                items: [
                  for (final u in page.items)
                    DropdownMenuItem(value: u.id, child: Text('${u.name} · ${u.role.label}')),
                ],
                onChanged: (v) => setState(() => _assigneeId = v),
              ),
            ),
            if (_error != null) ...[
              Gap.md,
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            Gap.xl,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ghairi'),
                ),
                Gap.sm,
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Inahifadhi...' : (_isEdit ? 'Hifadhi' : 'Tengeneza')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
