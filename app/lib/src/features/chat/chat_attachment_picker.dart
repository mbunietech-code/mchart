import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_color.dart';

class PickedAttachment {
  PickedAttachment(this.path, this.name);
  final String path;
  final String? name;
}

enum _Source { camera, cameraVideo, gallery, audio, document }

/// Opens a bottom sheet to pick a photo, video, gallery item, audio file, or
/// document to attach to an outgoing chat message. Returns null if the user
/// backed out or the underlying picker returned nothing.
Future<PickedAttachment?> pickChatAttachment(
  BuildContext context, {
  bool audioOnly = false,
}) async {
  if (audioOnly) {
    try {
      final res = await FilePicker.pickFiles(type: FileType.audio);
      final file = res?.files.single;
      return file?.path == null
          ? null
          : PickedAttachment(file!.path!, file.name);
    } catch (_) {
      return null;
    }
  }

  final choice = await showModalBottomSheet<_Source>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SourceSheet(),
  );
  if (choice == null) return null;

  try {
    switch (choice) {
      case _Source.camera:
        final x = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        return x == null ? null : PickedAttachment(x.path, x.name);
      case _Source.cameraVideo:
        final x = await ImagePicker().pickVideo(source: ImageSource.camera);
        return x == null ? null : PickedAttachment(x.path, x.name);
      case _Source.gallery:
        final x = await ImagePicker().pickMedia(imageQuality: 85);
        return x == null ? null : PickedAttachment(x.path, x.name);
      case _Source.audio:
        final res = await FilePicker.pickFiles(type: FileType.audio);
        final file = res?.files.single;
        return file?.path == null
            ? null
            : PickedAttachment(file!.path!, file.name);
      case _Source.document:
        final res = await FilePicker.pickFiles(withData: false);
        final file = res?.files.single;
        return file?.path == null
            ? null
            : PickedAttachment(file!.path!, file.name);
    }
  } catch (_) {
    return null;
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

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
              onTap: () => Navigator.of(context).pop(_Source.camera),
            ),
            _Tile(
              icon: Icons.videocam_outlined,
              label: 'Record video',
              onTap: () => Navigator.of(context).pop(_Source.cameraVideo),
            ),
            _Tile(
              icon: Icons.photo_library_outlined,
              label: 'Photo or video from gallery',
              onTap: () => Navigator.of(context).pop(_Source.gallery),
            ),
            _Tile(
              icon: Icons.audiotrack_outlined,
              label: 'Audio file',
              onTap: () => Navigator.of(context).pop(_Source.audio),
            ),
            _Tile(
              icon: Icons.insert_drive_file_outlined,
              label: 'Document',
              onTap: () => Navigator.of(context).pop(_Source.document),
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
