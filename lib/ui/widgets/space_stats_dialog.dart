import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
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
              child: Text('Could not compute stats: ${snap.error}'),
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
          return SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'Posts',
                    children: [
                      _StatRow(label: 'Total', value: '${s.totalPosts}'),
                      _StatRow(label: 'Notes', value: '${s.notes}'),
                      _StatRow(label: 'Bookmarks', value: '${s.bookmarks}'),
                      _StatRow(
                        label: 'Replies (nested)',
                        value: '${s.replies}',
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _Section(
                    title: 'Drive',
                    children: [
                      _StatRow(label: 'Files', value: '${s.files}'),
                    ],
                  ),
                  const Divider(height: 24),
                  _Section(
                    title: 'Storage',
                    children: [
                      _StatRow(
                        label: 'Space size',
                        value: formatBytes(s.storageBytes),
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
          child: const Text('Close'),
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