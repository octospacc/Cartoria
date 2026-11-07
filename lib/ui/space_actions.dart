import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/space_archive.dart';
import '../data/store.dart';
import '../platform/file_save.dart';

Future<void> exportSpaceZip(
  BuildContext context,
  VaultStore store,
  Space space,
) async {
  final files = store.filesForSpace(space.id);
  if (files.isEmpty) {
    // Nothing to export but a space; still allow, no dialog.
    await _doExport(context, store, space, ExportMediaMode.noMedia);
    return;
  }

  final offloadedCount = store.offloadedFileIds(space.id).length;

  final mode = await showDialog<ExportMediaMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Export "${space.name}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExportOption(
            mode: ExportMediaMode.full,
            title: 'Full',
            description: 'Includes every file. Offloaded files are '
                '${offloadedCount == 0 ? "none" : "$offloadedCount and "}'
                'downloaded from the sync remote before the zip is built. '
                'Slowest, but the export is self-contained.',
            disabled: false,
            onTap: (m) => Navigator.pop(ctx, m),
          ),
          const SizedBox(height: 8),
          _ExportOption(
            mode: ExportMediaMode.onDiskOnly,
            title: 'On-disk only',
            description: 'Includes files currently stored on this device. '
                '${offloadedCount == 0 ? "No files are offloaded." : "$offloadedCount offloaded file${offloadedCount == 1 ? "" : "s"} skipped."} '
                'File references are preserved in the export; re-importing '
                'the full zip (or syncing) later can restore the missing '
                'blobs.',
            disabled: false,
            onTap: (m) => Navigator.pop(ctx, m),
          ),
          const SizedBox(height: 8),
          _ExportOption(
            mode: ExportMediaMode.noMedia,
            title: 'Without media',
            description: 'No files at all. Only the text (notes, bookmarks) '
                'and file references. Smallest export; every file will '
                'appear as missing on import until restored.',
            disabled: false,
            onTap: (m) => Navigator.pop(ctx, m),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (mode == null || !context.mounted) return;
  await _doExport(context, store, space, mode);
}

Future<void> _doExport(
  BuildContext context,
  VaultStore store,
  Space space,
  ExportMediaMode mode,
) async {
  try {
    final bytes = await store.exportSpaceZip(space.id, mode: mode);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9T]'), '')
        .substring(0, 15);
    final suffix = switch (mode) {
      ExportMediaMode.full => '',
      ExportMediaMode.onDiskOnly => '-local',
      ExportMediaMode.noMedia => '-lite',
    };
    await saveOrShareFile(bytes, 'space-${space.name}$suffix-$stamp.zip');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _ExportOption extends StatelessWidget {
  final ExportMediaMode mode;
  final String title;
  final String description;
  final bool disabled;
  final void Function(ExportMediaMode) onTap;

  const _ExportOption({
    required this.mode,
    required this.title,
    required this.description,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: disabled ? null : () => onTap(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}