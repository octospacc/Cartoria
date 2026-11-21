import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/space_archive.dart';
import '../data/store.dart';
import '../l10n/l10n.dart';
import '../platform/file_save.dart';

Future<void> exportSpaceZip(
  BuildContext context,
  VaultStore store,
  Space space,
) async {
  final l = context.l10n;
  final files = store.filesForSpace(space.id);
  if (files.isEmpty) {
    await _doExport(context, store, space, ExportMediaMode.noMedia);
    return;
  }

  final offloadedCount = store.offloadedFileIds(space.id).length;

  final mode = await showDialog<ExportMediaMode>(
    context: context,
    builder: (ctx) {
      final ml = ctx.l10n;
      return AlertDialog(
        title: Text(ml.spaceActionsExportTitle(space.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ExportOption(
              mode: ExportMediaMode.full,
              title: ml.spaceActionsFull,
              description: ml.spaceActionsFullBody(offloadedCount),
              disabled: false,
              onTap: (m) => Navigator.pop(ctx, m),
            ),
            const SizedBox(height: 8),
            _ExportOption(
              mode: ExportMediaMode.onDiskOnly,
              title: ml.spaceActionsOnDisk,
              description: ml.spaceActionsOnDiskBody(offloadedCount),
              disabled: false,
              onTap: (m) => Navigator.pop(ctx, m),
            ),
            const SizedBox(height: 8),
            _ExportOption(
              mode: ExportMediaMode.noMedia,
              title: ml.spaceActionsNoMedia,
              description: ml.spaceActionsNoMediaBody,
              disabled: false,
              onTap: (m) => Navigator.pop(ctx, m),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ml.commonCancel),
          ),
        ],
      );
    },
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.spaceActionsExportFailed(e.toString()))),
      );
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