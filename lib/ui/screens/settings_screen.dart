import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/store.dart';
import '../../platform/file_save.dart';
import '../../util/format.dart';

class SettingsScreen extends StatefulWidget {
  final VaultStore store;
  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _retentionCtrl;
  List<BackupInfo> _backups = const [];
  bool _loadingBackups = true;
  bool _clearing = false;

  /// Name of the backup currently being exported or deleted. While
  /// set, other rows' action buttons are disabled — the underlying
  /// operations are quick but the export can hold a native save dialog
  /// open, and disallowing concurrent actions on other rows avoids the
  /// "two spinners, two dialogs" case.
  String? _busyName;

  @override
  void initState() {
    super.initState();
    final override = widget.store.backupRetentionCountOverride;
    _retentionCtrl = TextEditingController(
      text: override?.toString() ?? '',
    );
    _loadBackups();
  }

  @override
  void dispose() {
    _retentionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() => _loadingBackups = true);
    try {
      final backups = await widget.store.listBackups();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _loadingBackups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBackups = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not list backups: $e')),
      );
    }
  }

  Future<void> _saveRetention() async {
    final raw = _retentionCtrl.text.trim();
    int? count;
    if (raw.isNotEmpty) {
      count = int.tryParse(raw);
      if (count == null || count < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Retention must be a non-negative integer')),
        );
        return;
      }
    }
    try {
      await widget.store.setBackupRetentionCount(count);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == null
                ? 'Retention reset to default'
                : count == 0
                    ? 'Pre-pull backups disabled'
                    : 'Retention set to $count',
          ),
        ),
      );
      await _loadBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _clearAllBackups() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Clear ${_backups.length} backup${_backups.length == 1 ? "" : "s"}?'),
        content: const Text(
          'Deletes every pre-pull backup. Current vault data is not '
          'affected. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      await widget.store.clearAllBackups();
      if (!mounted) return;
      await _loadBackups();
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _exportBackup(BackupInfo b) async {
    setState(() => _busyName = b.name);
    try {
      final bytes = await widget.store.readBackupBytes(b.name);
      await saveOrShareFile(bytes, b.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  Future<void> _deleteBackup(BackupInfo b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${b.name}"?'),
        content: const Text(
          'Deletes this backup. Other backups and current vault data '
          'are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyName = b.name);
    try {
      await widget.store.deleteBackup(b.name);
      if (!mounted) return;
      await _loadBackups();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSize = _backups.fold<int>(0, (sum, b) => sum + b.sizeBytes);
    final effective = widget.store.effectiveBackupRetentionCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'BACKUPS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A backup of the vault is created before each pull, so a bad '
            'pull cannot destroy unpushed local changes. Old backups are '
            'deleted automatically beyond the retention limit.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _retentionCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Retention (number of backups)',
              hintText: 'Default: $effective',
              helperText: 'Leave empty to use the default. Set to 0 to '
                  'disable pre-pull backups entirely.',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check, size: 18),
                tooltip: 'Save',
                onPressed: _saveRetention,
              ),
            ),
            onSubmitted: (_) => _saveRetention(),
          ),
          const SizedBox(height: 6),
          Text(
            'Currently keeping up to $effective '
            'backup${effective == 1 ? "" : "s"}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  _loadingBackups
                      ? 'Loading backups…'
                      : '${_backups.length} backup'
                          '${_backups.length == 1 ? "" : "s"} · '
                          '${formatBytes(totalSize)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_backups.isNotEmpty)
                TextButton.icon(
                  onPressed:
                      _clearing || _busyName != null ? null : _clearAllBackups,
                  icon: _clearing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          if (_loadingBackups)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No backups yet. Backups are created automatically before '
                'each pull.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                children: _backups.map((b) {
                  final isBusy = _busyName == b.name;
                  final anyBusy = _busyName != null;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.archive_outlined, size: 20),
                    title: Text(b.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${formatBytes(b.sizeBytes)} · '
                      '${_formatDate(b.modified)}',
                    ),
                    trailing: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download_outlined,
                                    size: 20),
                                tooltip: 'Export',
                                visualDensity: VisualDensity.compact,
                                onPressed: anyBusy
                                    ? null
                                    : () => _exportBackup(b),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20),
                                tooltip: 'Delete',
                                visualDensity: VisualDensity.compact,
                                onPressed: anyBusy
                                    ? null
                                    : () => _deleteBackup(b),
                              ),
                            ],
                          ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime t) {
    final local = t.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}