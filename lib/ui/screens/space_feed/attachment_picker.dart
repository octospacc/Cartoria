import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../widgets/recall_files_sheet.dart';
import '../../../platform/clipboard_files.dart';

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
            leading: const Icon(Icons.content_paste),
            title: const Text('Paste from clipboard'),
            onTap: () => Navigator.pop(ctx, 'paste'),
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
    try {
      final file = await openFile();
      if (file == null) return const [];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return const [];
      final f = await store.addFileFromBytes(
        spaceId: space.id,
        bytes: bytes,
        name: file.name,
      );
      return [f.id];
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return const [];
    }
  }

  if (choice == 'paste') {
    try {
      final files = await readClipboardFiles();
      if (files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No image or file found in clipboard. On web, try pressing '
                'Ctrl+V in the composer instead.',
              ),
            ),
          );
        }
        return const [];
      }
      final ids = <String>[];
      for (final f in files) {
        try {
          final file = await store.addFileFromBytes(
            spaceId: space.id,
            bytes: f.bytes,
            name: f.name,
          );
          ids.add(file.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Paste failed: $e')),
            );
          }
        }
      }
      return ids;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paste failed: $e')),
        );
      }
      return const [];
    }
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
