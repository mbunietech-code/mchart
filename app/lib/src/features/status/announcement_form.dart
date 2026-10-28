import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/announcement.dart';
import '../../theme/app_color.dart';
import '../../theme/app_spacing.dart';
import '../auth/auth_controller.dart';
import '../directory/directory_repository.dart';
import 'announcement_repository.dart';

/// Create or edit an announcement. Full screen on phones, a dialog on wide
/// layouts.
Future<void> showAnnouncementForm(
  BuildContext context,
  WidgetRef ref, {
  Announcement? existing,
}) {
  final narrow = MediaQuery.sizeOf(context).width < 720;
  if (narrow) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _AnnouncementForm(existing: existing, fullScreen: true),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: _AnnouncementForm(existing: existing),
      ),
    ),
  );
}

class _AnnouncementForm extends ConsumerStatefulWidget {
  const _AnnouncementForm({this.existing, this.fullScreen = false});
  final Announcement? existing;
  final bool fullScreen;

  @override
  ConsumerState<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<_AnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.body);
  late AnnouncementCategory _category =
      widget.existing?.category ?? AnnouncementCategory.notice;
  late int? _departmentId = widget.existing != null
      ? widget.existing!.departmentId
      : (ref.read(currentUserProvider)?.isAdmin ?? false)
      ? null
      : ref.read(currentUserProvider)?.departmentId;
  late bool _pinned = widget.existing?.pinned ?? false;
  late DateTime? _expiresAt = widget.existing?.expiresAt;
  XFile? _image;
  late bool _hasExistingImage = widget.existing?.imageUrl != null;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (x != null) setState(() => _image = x);
    } catch (e) {
      setState(() => _error = 'Could not open the gallery: $e');
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (!mounted) return;
    setState(
      () => _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final editing = widget.existing != null;
    try {
      await ref
          .read(announcementRepositoryProvider)
          .save(
            id: widget.existing?.id,
            category: _category,
            title: _title.text.trim(),
            body: _body.text.trim(),
            departmentId: _departmentId,
            pinned: _pinned,
            expiresAt: _expiresAt,
            imagePath: _image?.path,
            imageName: _image?.name,
            removeImage: editing && !_hasExistingImage && _image == null,
          );
      ref.invalidate(announcementsProvider);
      ref.invalidate(announcementUnreadProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing ? 'Announcement updated' : 'Announcement published',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.isValidation
            ? (e.firstErrorFor('department_id') ??
                  e.firstErrorFor('image') ??
                  e.firstErrorFor('expires_at') ??
                  e.message)
            : e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider);
    final isAdmin = me?.isAdmin ?? false;
    final departments = ref.watch(departmentsProvider).valueOrNull ?? const [];
    final editing = widget.existing != null;

    final form = Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: !widget.fullScreen,
        padding: const EdgeInsets.all(20),
        children: [
          if (!widget.fullScreen) ...[
            Text(
              editing ? 'Edit announcement' : 'New announcement',
              style: t.titleLarge,
            ),
            Gap.lg,
          ],
          Text('Category', style: t.labelLarge),
          Gap.sm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in AnnouncementCategory.values)
                ChoiceChip(
                  selected: _category == c,
                  showCheckmark: false,
                  avatar: Icon(
                    c.icon,
                    size: 16,
                    color: _category == c ? Colors.white : c.color,
                  ),
                  label: Text(c.label),
                  labelStyle: TextStyle(
                    color: _category == c ? Colors.white : AppColor.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: c.color,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          Gap.lg,
          TextFormField(
            controller: _title,
            maxLength: 150,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Company meeting on Friday',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
          ),
          Gap.sm,
          TextFormField(
            controller: _body,
            minLines: 4,
            maxLines: 10,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
              hintText:
                  'All MbuniTech team members are required to attend a company meeting on Friday at 10:00 AM.',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter the message' : null,
          ),
          Gap.sm,
          DropdownButtonFormField<int?>(
            initialValue: _departmentId,
            decoration: const InputDecoration(labelText: 'Audience'),
            items: [
              if (isAdmin)
                const DropdownMenuItem(value: null, child: Text('Everyone')),
              for (final d in departments)
                if (isAdmin || d.id == me?.departmentId)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: isAdmin
                ? (v) => setState(() => _departmentId = v)
                : null, // managers post to their own department only
          ),
          Gap.sm,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
            title: const Text('Pin to the top'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: Text(
              _expiresAt == null
                  ? 'No expiry'
                  : 'Archive after ${Fmt.shortDate(_expiresAt!)} ${Fmt.time(_expiresAt!)}',
            ),
            subtitle: const Text('Expired announcements move to Archived'),
            trailing: _expiresAt == null
                ? TextButton(onPressed: _pickExpiry, child: const Text('Set'))
                : IconButton(
                    tooltip: 'Remove expiry',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _expiresAt = null),
                  ),
          ),
          Gap.sm,
          _ImageField(
            picked: _image,
            existingUrl: _hasExistingImage ? widget.existing?.imageUrl : null,
            onPick: _pickImage,
            onRemove: () => setState(() {
              _image = null;
              _hasExistingImage = false;
            }),
          ),
          if (_error != null) ...[
            Gap.md,
            Text(_error!, style: const TextStyle(color: AppColor.danger)),
          ],
          if (!widget.fullScreen) ...[
            Gap.lg,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Gap.sm,
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _busy ? 'Saving…' : (editing ? 'Save' : 'Publish'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!widget.fullScreen) return form;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit announcement' : 'New announcement'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Saving…' : (editing ? 'Save' : 'Publish')),
            ),
          ),
        ],
      ),
      body: SafeArea(child: form),
    );
  }
}

class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.picked,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? picked;
  final String? existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Widget? preview;
    if (picked != null) {
      preview = kIsWeb
          ? Image.network(picked!.path, fit: BoxFit.cover)
          : Image.file(File(picked!.path), fit: BoxFit.cover);
    } else if (existingUrl != null) {
      preview = Image.network(
        announcementImageUrl(existingUrl!),
        fit: BoxFit.cover,
      );
    }

    if (preview == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.image_outlined),
        label: const Text('Add image (optional)'),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(height: 160, width: double.infinity, child: preview),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton.filledTonal(
            tooltip: 'Remove image',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}
