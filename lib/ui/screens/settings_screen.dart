import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../platform/file_save.dart';
import '../../util/format.dart';
import '../widgets/escape_back.dart';

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
        SnackBar(
          content:
              Text(context.l10n.settingsListBackupsFailed(e.toString())),
        ),
      );
    }
  }

  Future<void> _saveRetention() async {
    final l = context.l10n;
    final raw = _retentionCtrl.text.trim();
    int? count;
    if (raw.isNotEmpty) {
      count = int.tryParse(raw);
      if (count == null || count < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.settingsRetentionInvalid)),
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
                ? l.settingsRetentionReset
                : count == 0
                    ? l.settingsRetentionDisabled
                    : l.settingsRetentionSaved(count),
          ),
        ),
      );
      await _loadBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsSaveFailed(e.toString()))),
      );
    }
  }

  Future<void> _clearAllBackups() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsBackupsClearTitle(_backups.length)),
        content: Text(l.settingsBackupsClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonClear),
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
          SnackBar(
            content:
                Text(context.l10n.settingsExportFailed(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  Future<void> _deleteBackup(BackupInfo b) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsBackupDeleteTitle(b.name)),
        content: Text(l.settingsBackupDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete),
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
          SnackBar(
            content:
                Text(context.l10n.settingsDeleteFailed(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final totalSize =
        _backups.fold<int>(0, (sum, b) => sum + b.sizeBytes);
    final effective = widget.store.effectiveBackupRetentionCount;

    return EscapeBack(
      child: Scaffold(
        appBar: AppBar(title: Text(l.settingsTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader(theme, l.settingsLanguageSection),
            const SizedBox(height: 8),
            Text(
              l.settingsLanguageDescription,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: widget.store.locale?.languageCode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l.settingsLanguageSystem),
                ),
                DropdownMenuItem<String?>(
                  value: 'en',
                  child: Text(l.settingsLanguageEnglish),
                ),
                DropdownMenuItem<String?>(
                  value: 'it',
                  child: Text(l.settingsLanguageItalian),
                ),
              ],
              onChanged: (code) async {
                await widget.store.setLocale(code);
              },
            ),
            const SizedBox(height: 24),
            _sectionHeader(theme, l.settingsBackupsSection),
            const SizedBox(height: 8),
            Text(
              l.settingsBackupsDescription,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _retentionCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.settingsRetentionLabel,
                helperText: l.settingsRetentionHelper,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  tooltip: l.settingsRetentionSaveTooltip,
                  onPressed: _saveRetention,
                ),
              ),
              onSubmitted: (_) => _saveRetention(),
            ),
            const SizedBox(height: 6),
            Text(
              l.settingsRetentionCurrent(effective),
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
                        ? l.settingsBackupsLoading
                        : '${l.settingsBackupsCount(_backups.length)} · '
                            '${formatBytes(totalSize)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (_backups.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearing || _busyName != null
                        ? null
                        : _clearAllBackups,
                    icon: _clearing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: Text(l.settingsBackupsClearAll),
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
                  l.settingsBackupsEmpty,
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
                      leading:
                          const Icon(Icons.archive_outlined, size: 20),
                      title:
                          Text(b.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${formatBytes(b.sizeBytes)} · '
                        '${_formatDate(b.modified)}',
                      ),
                      trailing: isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.download_outlined,
                                      size: 20),
                                  tooltip:
                                      l.settingsBackupsExportTooltip,
                                  visualDensity:
                                      VisualDensity.compact,
                                  onPressed: anyBusy
                                      ? null
                                      : () => _exportBackup(b),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20),
                                  tooltip:
                                      l.settingsBackupsDeleteTooltip,
                                  visualDensity:
                                      VisualDensity.compact,
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
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String text) => Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      );

  String _formatDate(DateTime t) {
    final local = t.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}