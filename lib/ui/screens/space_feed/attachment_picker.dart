import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/clipboard_files.dart';
import '../../widgets/recall_files_sheet.dart';

/// Lets the user either upload new file(s) or recall existing ones from
/// the drive. Returns the IDs of the files to attach (empty list if
/// cancelled, or if every pick failed).
Future<List<String>> pickOrRecallFiles(
  BuildContext context,
  VaultStore store,
  Space space,
) async {
  final l = context.l10n;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final ml = ctx.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(ml.attachmentUpload),
              onTap: () => Navigator.pop(ctx, 'new'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(ml.attachmentPaste),
              onTap: () => Navigator.pop(ctx, 'paste'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(ml.attachmentRecall),
              onTap: () => Navigator.pop(ctx, 'existing'),
            ),
          ],
        ),
      );
    },
  );
  if (choice == null) return const [];

  if (choice == 'new') {
    try {
      final files = await openFiles();
      if (files.isEmpty) return const [];

      final ids = <String>[];
      final failedNames = <String>[];

      for (final file in files) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            failedNames.add(file.name);
            continue;
          }
          final f = await store.addFileFromBytes(
            spaceId: space.id,
            bytes: bytes,
            name: file.name,
          );
          ids.add(f.id);
        } catch (e) {
          debugPrint('Upload failed for ${file.name}: $e');
          failedNames.add(file.name);
        }
      }

      if (failedNames.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.attachmentUploadFailedCount(failedNames.length)),
          ),
        );
      }

      return ids;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.attachmentUploadFailed(e.toString()))),
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
            SnackBar(content: Text(l.attachmentPasteEmpty)),
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
              SnackBar(content: Text(l.attachmentPasteFailed(e.toString()))),
            );
          }
        }
      }
      return ids;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.attachmentPasteFailed(e.toString()))),
        );
      }
      return const [];
    }
  }

  if (choice == 'existing') {
    if (store.filesForSpace(space.id).isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.attachmentDriveEmpty)),
        );
      }
      return const [];
    }
    return RecallFilesSheet.show(context, store, space);
  }

  return const [];
}
