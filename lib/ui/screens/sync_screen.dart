import 'package:flutter/material.dart';

import '../../data/sync/sync_config.dart';
import '../../data/sync/sync_provider.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../widgets/escape_back.dart';
import 'sync_edit_screen.dart';

class SyncScreen extends StatelessWidget {
  final VaultStore store;
  const SyncScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EscapeBack(
        child: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final configs = store.syncConfigs;
        return Scaffold(
          appBar: AppBar(title: Text(l.syncTitle)),
          body: configs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.syncEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
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

class _ConfigTile extends StatelessWidget {
  final VaultStore store;
  final SyncConfig config;

  const _ConfigTile({required this.store, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final subtitleParts = <String>[
      '${config.provider.emoji} ${config.provider.label}',
      if (config.host != null && config.host!.isNotEmpty) config.host!,
      '${config.owner}/${config.repo}',
      config.branch,
    ];
    final spaces = _spacesSummary(l);
    if (spaces != null) subtitleParts.add(spaces);
    if (config.isPrimary) subtitleParts.add(l.syncVaultDataSuffix);

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
                l.syncPrimaryBadge,
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
              l.syncLastSynced(_fmtTime(config.lastSyncedAt!)),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            tooltip: l.syncPushNow,
            visualDensity: VisualDensity.compact,
            onPressed: () => _runSync(context, isPush: true),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined, size: 20),
            tooltip: l.syncPullNow,
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
              PopupMenuItem(value: 'edit', child: Text(l.syncMenuEdit)),
              if (!config.isPrimary)
                PopupMenuItem(
                    value: 'primary', child: Text(l.syncMenuSetPrimary)),
              PopupMenuItem(value: 'delete', child: Text(l.syncMenuDelete)),
            ],
          ),
        ],
      ),
      onTap: () => _openEdit(context),
    );
  }

  String? _spacesSummary(AppLocalizations l) {
    final ids = config.spaceIds;
    if (ids == null) return l.syncAllSpaces;
    if (ids.isEmpty) return l.syncNoSpaces;
    return l.syncSpacesCount(ids.length);
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
    final l = context.l10n;
    await store.saveSyncConfig(config.copyWith(isPrimary: true));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.syncPrimaryNow(config.name))),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncDeleteTitle(config.name)),
        content: Text(
          config.isPrimary && store.syncConfigs.length > 1
              ? l.syncDeleteBodyPrimary
              : l.syncDeleteBody,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (ok == true) await store.removeSyncConfig(config.id);
  }

  Future<void> _runSync(BuildContext context, {required bool isPush}) async {
    final l = context.l10n;
    final token = await store.loadSyncToken(config.id);
    if (!context.mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.syncNoTokenSnack(config.name))),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPush
            ? l.syncPushConfirmTitle(config.name)
            : l.syncPullConfirmTitle(config.name)),
        content: Text(
          isPush ? l.syncPushConfirmBody : l.syncPullConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPush ? l.syncPushButton : l.syncPullButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

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
        final l = context.l10n;
        setState(() {
          _done = true;
          _summary = l.syncPushResultLine(r.created, r.updated, r.deleted);
        });
      } else {
        final r = await widget.store.syncPull(
          widget.configId,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        if (!mounted) return;
        final l = context.l10n;
        setState(() {
          _done = true;
          _summary = l.syncPullResultLine(r.added, r.updated, r.deleted);
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
    final l = context.l10n;

    return AlertDialog(
      title: Text(widget.isPush
          ? l.syncDialogPushTitle(widget.configName)
          : l.syncDialogPullTitle(widget.configName)),
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
                _progress?.message ?? l.syncProgressStarting,
                style: theme.textTheme.bodySmall,
              ),
            ] else if (_error != null) ...[
              Row(
                children: [
                  Icon(Icons.error, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        Text(l.syncFailed, style: theme.textTheme.titleSmall),
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
                    child: Text(l.syncComplete,
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
                child: Text(l.syncDialogClose),
              ),
            ]
          : const [],
    );
  }
}