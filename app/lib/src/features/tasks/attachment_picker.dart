import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_color.dart';
import 'task_repository.dart';

/// Opens a bottom sheet letting the user attach a photo, video, gallery
/// item, or any document/audio file to a task, uploads it, and refreshes
/// the task detail on success.
Future<void> pickAndUploadTaskAttachment(
  BuildContext context,
  WidgetRef ref,
  int taskId,
) async {
  final choice = await showModalBottomSheet<_AttachSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AttachSourceSheet(),
  );
  if (choice == null || !context.mounted) return;

  String? path;
  String? name;

  try {
    switch (choice) {
      case _AttachSource.camera:
        final x = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        path = x?.path;
        name = x?.name;
      case _AttachSource.cameraVideo:
        final x = await ImagePicker().pickVideo(source: ImageSource.camera);
        path = x?.path;
        name = x?.name;
      case _AttachSource.gallery:
        final x = await ImagePicker().pickMedia(imageQuality: 85);
        path = x?.path;
        name = x?.name;
      case _AttachSource.file:
        final res = await FilePicker.pickFiles(withData: false);
        path = res?.files.single.path;
        name = res?.files.single.name;
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open picker: $e')));
    }
    return;
  }

  if (path == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Uploading attachment...')),
  );

  try {
    await ref
        .read(taskRepositoryProvider)
        .uploadAttachment(taskId, path, fileName: name);
    ref.invalidate(taskDetailProvider(taskId));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Attachment added.')));
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
  }
}

enum _AttachSource { camera, cameraVideo, gallery, file }

class _AttachSourceSheet extends StatelessWidget {
  const _AttachSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Tile(
              icon: Icons.photo_camera_outlined,
              label: 'Take photo',
              onTap: () => Navigator.of(context).pop(_AttachSource.camera),
            ),
            _Tile(
              icon: Icons.videocam_outlined,
              label: 'Record video',
              onTap: () => Navigator.of(context).pop(_AttachSource.cameraVideo),
            ),
            _Tile(
              icon: Icons.photo_library_outlined,
              label: 'Photo or video from gallery',
              onTap: () => Navigator.of(context).pop(_AttachSource.gallery),
            ),
            _Tile(
              icon: Icons.insert_drive_file_outlined,
              label: 'Document or audio file',
              onTap: () => Navigator.of(context).pop(_AttachSource.file),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColor.brand),
      title: Text(label),
      onTap: onTap,
    );
  }
}
