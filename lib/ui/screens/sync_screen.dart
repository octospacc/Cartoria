import 'package:flutter/material.dart';

import '../../data/sync/sync_config.dart';
import '../../data/sync/sync_provider.dart';
import '../../data/store.dart';
import '../widgets/escape_back.dart';
import 'sync_edit_screen.dart';

class SyncScreen extends StatelessWidget {
  final VaultStore store;
  const SyncScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return EscapeBack(
        child: AnimatedBuilder(
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
    ));
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
      '${config.provider.emoji} ${config.provider.label}',
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            tooltip: 'Push now',
            visualDensity: VisualDensity.compact,
            onPressed: () => _runSync(context, isPush: true),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined, size: 20),
            tooltip: 'Pull now',
            visualDensity: VisualDensity.compact,
            onPressed: () => _runSync(context, isPush: false),
          ),
          PopupMenuButton<String>(
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

  Future<void> _runSync(BuildContext context, {required bool isPush}) async {
    // 1. Token must exist before we bother with the confirmation.
    final token = await store.loadSyncToken(config.id);
    if (!context.mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No token for "${config.name}". Open Edit to add one.',
          ),
        ),
      );
      return;
    }

    // 2. Confirm the action (both directions can overwrite data).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPush ? 'Push "${config.name}"?' : 'Pull "${config.name}"?',
        ),
        content: Text(
          isPush
              ? 'Uploads local changes to the remote. Unpulled remote '
                  'changes will be overwritten.'
              : 'Overwrites local files in this config\'s scope with the '
                  'remote version. A backup of the vault is saved first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPush ? 'Push' : 'Pull'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    // 3. Progress dialog drives the actual sync. Non-dismissible because
    //    the sync is in flight; the user can't open another config's
    //    push/pull while one is running, which is the desired safety
    //    guarantee for overlapping writes.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SyncProgressDialog(
        store: store,
        configId: config.id,
        configName: config.name,
        isPush: isPush,
      ),
    );
  }
}

/// Modal dialog that runs a push or pull and reports progress inline.
///
/// Three-phase state machine:
///   - running: progress bar + message, no actions, barrier disabled
///   - success: checkmark + summary, single Close button
///   - failure: error icon + exception text, single Close button
///
/// The sync itself is started in [initState], so the dialog is purely a
/// view onto a future that has already been launched. Closing the
/// dialog cannot abort the sync — it has already completed by the time
/// Close becomes available.
class _SyncProgressDialog extends StatefulWidget {
  final VaultStore store;
  final String configId;
  final String configName;
  final bool isPush;

  const _SyncProgressDialog({
    required this.store,
    required this.configId,
    required this.configName,
    required this.isPush,
  });

  @override
  State<_SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<_SyncProgressDialog> {
  SyncProgress? _progress;
  bool _done = false;
  String? _error;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      if (widget.isPush) {
        final r = await widget.store.syncPush(
          widget.configId,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        if (!mounted) return;
        final parts = <String>[
          'Pushed ${r.pushed} file${r.pushed == 1 ? "" : "s"}',
          if (r.deleted > 0) 'deleted ${r.deleted}',
          if (r.skippedLarge > 0) 'skipped ${r.skippedLarge} large',
          if (r.skippedOffloaded > 0) '${r.skippedOffloaded} offloaded',
        ];
        setState(() {
          _done = true;
          _summary = parts.join(', ');
        });
      } else {
        final r = await widget.store.syncPull(
          widget.configId,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        if (!mounted) return;
        final parts = <String>[
          'Pulled ${r.pulled} file${r.pulled == 1 ? "" : "s"}',
          if (r.deleted > 0) 'deleted ${r.deleted}',
          if (r.offloaded > 0) '${r.offloaded} offloaded',
        ];
        setState(() {
          _done = true;
          _summary = parts.join(', ');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _done = true;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        '${widget.isPush ? "Push" : "Pull"} "${widget.configName}"',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_done) ...[
              LinearProgressIndicator(value: _progress?.fraction),
              const SizedBox(height: 12),
              Text(
                _progress?.message ?? 'Starting…',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (_error != null) ...[
              Row(
                children: [
                  Icon(Icons.error, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        Text('Sync failed', style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Sync complete',
                        style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_summary ?? '', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: _done
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ]
          : const [],
    );
  }
}
