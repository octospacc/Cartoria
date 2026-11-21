library sync_edit_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/store.dart';
import '../../data/sync/sync_config.dart';
import '../../data/sync/sync_provider.dart';
import '../../l10n/l10n.dart';
import '../widgets/escape_back.dart';

part 'sync_edit/space_selector.dart';

class SyncEditScreen extends StatefulWidget {
  final VaultStore store;
  final SyncConfig? existing;
  const SyncEditScreen({super.key, required this.store, this.existing});

  @override
  State<SyncEditScreen> createState() => _SyncEditScreenState();
}

class _SyncEditScreenState extends State<SyncEditScreen> {
  late String _id;
  late TextEditingController _name;
  late SyncProviderKind _provider;
  late TextEditingController _host;
  late TextEditingController _owner;
  late TextEditingController _repo;
  late TextEditingController _branch;
  late TextEditingController _prefix;
  late TextEditingController _keepLocal;
  late TextEditingController _token;
  late Set<String>? _spaceIds;

  bool _isPrimary = false;
  bool _tokenStored = false;
  bool _showTokenInput = false;
  bool _busy = false;
  String? _status;
  String? _error;
  SyncProgress? _progress;

  Map<String, String?>? _remoteSpaces;
  bool _loadingRemoteSpaces = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _id = e?.id ?? const Uuid().v7();
    _name = TextEditingController(text: e?.name ?? '');
    _provider = e?.provider ?? SyncProviderKind.github;
    _host = TextEditingController(text: e?.host ?? '');
    _owner = TextEditingController(text: e?.owner ?? '');
    _repo = TextEditingController(text: e?.repo ?? '');
    _branch = TextEditingController(text: e?.branch ?? 'main');
    _prefix = TextEditingController(text: e?.pathPrefix ?? '');
    _keepLocal =
        TextEditingController(text: e?.keepLocalFileCount?.toString() ?? '');
    _spaceIds = e?.spaceIds != null ? {...e!.spaceIds!} : null;
    _isPrimary = e?.isPrimary ?? widget.store.syncConfigs.isEmpty;
    _token = TextEditingController();
    _loadTokenState();
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _owner.dispose();
    _repo.dispose();
    _branch.dispose();
    _prefix.dispose();
    _keepLocal.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _loadTokenState() async {
    final token = await widget.store.loadSyncToken(_id);
    if (!mounted) return;
    setState(() {
      _tokenStored = token != null && token.isNotEmpty;
      _showTokenInput = !_tokenStored;
    });
  }

  SyncConfig _buildCurrent() {
    final name = _name.text.trim().isEmpty
        ? '${_owner.text.trim()}/${_repo.text.trim()}'
        : _name.text.trim();
    return SyncConfig(
      id: _id,
      name: name,
      isPrimary: _isPrimary,
      provider: _provider,
      host: SyncConfig.sanitizeHost(_host.text),
      owner: _owner.text.trim(),
      repo: _repo.text.trim(),
      branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
      pathPrefix: _prefix.text.trim(),
      spaceIds: _spaceIds,
      keepLocalFileCount: int.tryParse(_keepLocal.text.trim()),
      lastSyncedAt: widget.existing?.lastSyncedAt,
      lastCommitSha: widget.existing?.lastCommitSha,
    );
  }

  Future<bool> _save() async {
    final l = context.l10n;
    setState(() => _error = null);
    final config = _buildCurrent();
    if (config.owner.isEmpty || config.repo.isEmpty) {
      setState(() => _error =
          '${l.syncEditOwnerLabel} / ${l.syncEditRepoLabel}: required');
      return false;
    }

    final old = widget.store.syncConfigById(_id);
    if (old != null &&
        old.tokenKey != config.tokenKey &&
        _token.text.trim().isEmpty) {
      final hadToken =
          (await widget.store.loadSyncToken(_id))?.isNotEmpty ?? false;
      if (hadToken && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.syncEditReenterTitle),
            content: Text(l.syncEditReenterBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.l10n.commonCancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.l10n.syncEditSaveAnyway)),
            ],
          ),
        );
        if (proceed != true) return false;
      }
    }

    try {
      await widget.store.saveSyncConfig(config);
      if (_token.text.trim().isNotEmpty) {
        await widget.store.saveSyncToken(_id, _token.text.trim());
        _token.clear();
        await _loadTokenState();
      }
      if (mounted) setState(() => _status = l.syncEditSaved);
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return false;
    }
  }

  Future<void> _verify() async {
    final l = context.l10n;
    if (!await _save()) return;
    if (!_tokenStored && _token.text.trim().isEmpty) {
      setState(() => _error = l.syncEditTokenRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });

    try {
      await widget.store.verifySyncAccess(_id);
      if (!mounted) return;
      setState(() {
        _status = l.syncEditAccessVerified;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
      return;
    }

    unawaited(_loadRemoteSpaces());
  }

  Future<void> _loadRemoteSpaces() async {
    final l = context.l10n;
    if (_loadingRemoteSpaces) return;
    setState(() => _loadingRemoteSpaces = true);
    try {
      final spaces = await widget.store
          .listRemoteSpaces(_id)
          .timeout(const Duration(seconds: 25));
      if (mounted) {
        setState(() => _remoteSpaces = spaces);
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.syncEditRemoteLoadTimedOut)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.syncEditRemoteLoadFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRemoteSpaces = false);
    }
  }

  Future<void> _push() async {
    final l = context.l10n;
    if (!await _save()) return;
    if (!_tokenStored && _token.text.trim().isEmpty) {
      setState(() => _error = l.syncEditTokenRequired);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncEditPushConfirmTitle),
        content: Text(l.syncEditPushConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.syncPushButton)),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      _progress = null;
    });
    try {
      final r = await widget.store.syncPush(_id, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) {
        setState(() => _status =
            l.syncPushResultLine(r.created, r.updated, r.deleted));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    final l = context.l10n;
    if (!await _save()) return;
    if (!_tokenStored && _token.text.trim().isEmpty) {
      setState(() => _error = l.syncEditTokenRequired);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncEditPullConfirmTitle),
        content: Text(l.syncEditPullConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.syncPullButton)),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      _progress = null;
    });
    try {
      final r = await widget.store.syncPull(_id, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) {
        setState(() => _status =
            l.syncPullResultLine(r.added, r.updated, r.deleted));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final spaces = widget.store.spaces;
    final isNew = widget.existing == null;
    final onlyConfig = widget.store.syncConfigs.length <= 1 && !isNew;

    return EscapeBack(child: Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l.syncEditNewTitle : l.syncEditExistingTitle),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(l.syncEditSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_error!,
                    style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontFamily: 'monospace',
                        fontSize: 12)),
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_status!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          _section(theme, l.syncEditNameSection),
          TextField(
            controller: _name,
            enabled: !_busy,
            decoration: InputDecoration(
              hintText: l.syncEditNameHint,
              helperText: l.syncEditNameHelper,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _section(theme, l.syncEditRemoteSection),
          DropdownButtonFormField<SyncProviderKind>(
            value: _provider,
            decoration: InputDecoration(
              labelText: l.syncEditProviderLabel,
              border: const OutlineInputBorder(),
            ),
            items: SyncProviderKind.values
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(p.label),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: _busy
                ? null
                : (v) => setState(() => _provider = v ?? _provider),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _host,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l.syncEditHostLabel,
              hintText: _provider.defaultHost,
              helperText: l.syncEditHostHelper(_provider.defaultHost),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _owner,
            enabled: !_busy,
            decoration: InputDecoration(
                labelText: l.syncEditOwnerLabel,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repo,
            enabled: !_busy,
            decoration: InputDecoration(
                labelText: l.syncEditRepoLabel,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _branch,
                  enabled: !_busy,
                  decoration: InputDecoration(
                      labelText: l.syncEditBranchLabel,
                      border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _prefix,
                  enabled: !_busy,
                  decoration: InputDecoration(
                      labelText: l.syncEditPrefixLabel,
                      border: const OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section(theme, l.syncEditPrimarySection),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.syncEditPrimarySwitchTitle),
            subtitle: Text(
              _isPrimary
                  ? l.syncEditPrimarySubtitleOn
                  : onlyConfig
                      ? l.syncEditPrimarySubtitleOnly
                      : l.syncEditPrimarySubtitleOff,
            ),
            value: _isPrimary,
            onChanged: _busy || onlyConfig
                ? null
                : (v) => setState(() => _isPrimary = v),
          ),
          const SizedBox(height: 20),
          _section(theme, l.syncEditSpacesSection),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l.syncEditSpacesAll),
            value: true,
            groupValue: _spaceIds == null,
            onChanged: _busy ? null : (_) => setState(() => _spaceIds = null),
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l.syncEditSpacesSelected),
            value: true,
            groupValue: _spaceIds != null,
            onChanged: _busy ? null : (_) => setState(() => _spaceIds ??= {}),
          ),
          if (_spaceIds != null) ...[
            const SizedBox(height: 6),
            _SpaceCheckboxes(state: this),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _remoteSpaces == null
                        ? l.syncEditRemoteHintUnloaded
                        : l.syncEditRemoteHintLoaded(_remoteSpaces!.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed:
                      _busy || _loadingRemoteSpaces ? null : _loadRemoteSpaces,
                  icon: _loadingRemoteSpaces
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 16),
                  label: Text(l.syncEditLoadRemote),
                ),
              ],
            ),
            if (_remoteSpaces != null)
              Builder(builder: (ctx) {
                final local = widget.store.spaces.map((s) => s.id).toSet();
                final remoteOnly = _remoteSpaces!.keys
                    .where((id) => !local.contains(id))
                    .toList();
                final missing =
                    remoteOnly.where((id) => !_spaceIds!.contains(id)).length;
                if (missing == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l.syncEditMissingRemote(missing),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
          ],
          const SizedBox(height: 20),
          _section(theme, l.syncEditDriveSection),
          TextField(
            controller: _keepLocal,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.syncEditKeepLocalLabel,
              helperText: l.syncEditKeepLocalHelper,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _section(theme, l.syncEditTokenSection),
          if (_tokenStored && !_showTokenInput)
            Row(
              children: [
                const Icon(Icons.lock, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(l.syncEditTokenStored)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _showTokenInput = true),
                  child: Text(l.syncEditTokenChange),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await widget.store.clearSyncToken(_id);
                          await _loadTokenState();
                          if (mounted) setState(() {});
                        },
                  child: Text(l.syncEditTokenClear),
                ),
              ],
            )
          else
            TextField(
              controller: _token,
              enabled: !_busy,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l.syncEditTokenLabel,
                helperText: _provider == SyncProviderKind.github
                    ? l.syncEditTokenHelperGithub
                    : l.syncEditTokenHelperGitlab,
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _verify,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l.syncEditVerify),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _push,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(l.syncEditPushButton),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _pull,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l.syncEditPullButton),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            if (_progress != null) ...[
              LinearProgressIndicator(value: _progress!.fraction),
              const SizedBox(height: 6),
              Text(_progress!.message ?? '', style: theme.textTheme.bodySmall),
            ] else
              const LinearProgressIndicator(),
          ],
          const SizedBox(height: 40),
        ],
      ),
    ));
  }

  Widget _section(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: theme.textTheme.titleSmall),
      );
}