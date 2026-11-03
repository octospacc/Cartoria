import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../widgets/recall_files_sheet.dart';

/// Lets the user either upload a new file or recall one from the drive.
/// Returns the IDs of the files to attach (empty list if cancelled).
Future<List<String>> pickOrRecallFiles(
  BuildContext context,
  VaultStore store,
  Space space,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Upload a new file'),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Recall from drive'),
            onTap: () => Navigator.pop(ctx, 'existing'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return const [];

  if (choice == 'new') {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (bytes == null || picked == null) return const [];
    final f = await store.addFileFromBytes(
      spaceId: space.id,
      bytes: bytes,
      name: picked.name,
    );
    return [f.id];
  }

  if (choice == 'existing') {
    if (store.filesForSpace(space.id).isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive is empty')),
        );
      }
      return const [];
    }
    return RecallFilesSheet.show(context, store, space);
  }

  return const [];
}