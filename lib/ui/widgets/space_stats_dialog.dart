import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../util/format.dart';

class SpaceStatsDialog extends StatelessWidget {
  final VaultStore store;
  final Space space;

  const SpaceStatsDialog({
    super.key,
    required this.store,
    required this.space,
  });

  static Future<void> show(
      BuildContext context, VaultStore store, Space space) {
    return showDialog(
      context: context,
      builder: (_) => SpaceStatsDialog(store: store, space: space),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          Text(space.icon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(space.name, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: FutureBuilder<SpaceStats>(
        future: store.computeStats(space.id),
        builder: (context, snap) {
          if (snap.hasError) {
            return SizedBox(
              width: 300,
              child: Text(l.spaceStatsCouldNotCompute(snap.error.toString())),
            );
          }
          if (!snap.hasData) {
            return const SizedBox(
              width: 300,
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final s = snap.data!;
          final theme = Theme.of(context);
          return SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: l.spaceStatsContent,
                    children: [
                      _StatRow(label: l.spaceStatsTotal, value: '${s.totalPosts}'),
                      _StatRow(label: l.spaceStatsNotes, value: '${s.notes}'),
                      _StatRow(label: l.spaceStatsBookmarks, value: '${s.bookmarks}'),
                      _StatRow(
                        label: l.spaceStatsReplies,
                        value: '${s.replies}',
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _Section(
                    title: l.spaceStatsDrive,
                    children: [
                      _StatRow(label: l.spaceStatsFiles, value: '${s.files}'),
                    ],
                  ),
                  const Divider(height: 24),
                  _Section(
                    title: l.spaceStatsStorage,
                    children: [
                      _StatRow(
                        label: l.spaceStatsSpaceSize,
                        value: formatBytes(s.storageBytes),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _Section(
                    title: l.spaceStatsLocation,
                    children: [
                      SelectableText(
                        p.join(store.vaultPath, space.id),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonClose),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}