import 'package:flutter/material.dart';

import '../../data/sync/sync_config.dart';
import '../../data/store.dart';
import 'sync_edit_screen.dart';

class SyncScreen extends StatelessWidget {
  final VaultStore store;
  const SyncScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final configs = store.syncConfigs;
        return Scaffold(
          appBar: AppBar(title: const Text('Sync')),
          body: configs.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  itemCount: configs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _ConfigTile(store: store, config: configs[i]),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openEdit(context, null),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, SyncConfig? config) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyncEditScreen(store: store, existing: config),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No sync repositories configured.\n\n'
          'A repository backs up some or all of your spaces to GitHub or '
          'GitLab. Exactly one repository is marked primary and '
          'additionally backs up vault-level data (hooks).\n\n'
          'Tap + to add one.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final VaultStore store;
  final SyncConfig config;

  const _ConfigTile({required this.store, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      config.provider.label,
      if (config.host != null && config.host!.isNotEmpty) config.host!,
      '${config.owner}/${config.repo}',
      config.branch,
    ];
    final spaces = _spacesSummary();
    if (spaces != null) subtitleParts.add(spaces);
    if (config.isPrimary) subtitleParts.add('+ vault data');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: config.isPrimary
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          config.isPrimary ? Icons.star : Icons.cloud_outlined,
          color: config.isPrimary
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              config.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (config.isPrimary) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRIMARY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitleParts.join(' · ')),
          if (config.lastSyncedAt != null)
            Text(
              'Last synced: ${_fmtTime(config.lastSyncedAt!)}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') _openEdit(context);
          if (v == 'primary') _setPrimary(context);
          if (v == 'delete') _confirmDelete(context);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit…')),
          if (!config.isPrimary)
            const PopupMenuItem(
                value: 'primary', child: Text('Set as primary')),
          const PopupMenuItem(value: 'delete', child: Text('Delete…')),
        ],
      ),
      onTap: () => _openEdit(context),
    );
  }

  String? _spacesSummary() {
    final ids = config.spaceIds;
    if (ids == null) return 'All spaces';
    if (ids.isEmpty) return 'No spaces';
    final n = ids.length;
    return '$n space${n == 1 ? "" : "s"}';
  }

  String _fmtTime(DateTime t) {
    final local = t.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyncEditScreen(store: store, existing: config),
      ),
    );
  }

  Future<void> _setPrimary(BuildContext context) async {
    await store.saveSyncConfig(config.copyWith(isPrimary: true));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('"${config.name}" is now the primary repository')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${config.name}"?'),
        content: Text(
          config.isPrimary && store.syncConfigs.length > 1
              ? 'This is the primary repository. Another will be '
                  'automatically promoted to primary. The remote repository '
                  'itself is not affected — only this app\'s configuration '
                  'for it.'
              : 'The remote repository itself is not affected — only this '
                  'app\'s configuration for it.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await store.removeSyncConfig(config.id);
  }
}
