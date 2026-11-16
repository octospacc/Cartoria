import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import '../../data/sync/sync_config.dart';
import '../../data/sync/sync_provider.dart';
import '../../data/store.dart';
import '../widgets/escape_back.dart';

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

  /// Remote spaces fetched from the config's repository. Null = not yet
  /// loaded (user hasn't verified or tapped "Load remote spaces").
  Map<String, String?>? _remoteSpaces;
  // Set<String>? _remoteSpaces;

  /// True while a remote-space fetch is in flight (spinner next to the
  /// button).
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
    setState(() => _error = null);
    final config = _buildCurrent();
    if (config.owner.isEmpty || config.repo.isEmpty) {
      setState(() => _error = 'Owner and repository are required');
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
            title: const Text('Re-enter token'),
            content: const Text(
              'The provider, host, owner, or repo changed. Tokens are '
              'scoped to that combination, so the previously saved token '
              'can\'t be reused here.\n\nYou\'ll need to enter a new token. '
              'Save anyway without a token?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save anyway')),
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
      if (mounted) setState(() => _status = 'Saved');
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return false;
    }
  }

  Future<void> _verify() async {
    if (!await _save()) return;
    if (!_tokenStored && _token.text.trim().isEmpty) {
      setState(() => _error = 'Enter a token first');
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
        _status = 'Access verified';
        // Free the UI immediately — the form should be usable while the
        // remote-space list loads in the background.
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

    // Fire-and-forget. `_loadRemoteSpaces` has its own timeout, its own
    // loading state on the button, and its own error handling; it must
    // not extend `_busy` or the whole form freezes for the duration of
    // the (potentially slow) name fetches.
    unawaited(_loadRemoteSpaces());
  }

  Future<void> _loadRemoteSpaces() async {
    if (_loadingRemoteSpaces) return;
    setState(() => _loadingRemoteSpaces = true);
    try {
      final spaces = await widget.store
          .listRemoteSpaces(_id)
          .timeout(const Duration(seconds: 25));
      if (mounted) {
        setState(() => _remoteSpaces = spaces);
        debugPrint('Loaded ${spaces.length} remote spaces');
      }
    } on TimeoutException {
      debugPrint('Timed out loading remote spaces');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Timed out loading remote spaces. Tap "Load remote spaces" '
              'to retry.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Could not load remote spaces: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load remote spaces: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRemoteSpaces = false);
    }
  }

  Future<void> _push() async {
    if (!await _save()) return;
    if (!_tokenStored && _token.text.trim().isEmpty) {
      setState(() => _error = 'Enter a token first');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push to remote?'),
        content: const Text(
          'This uploads the selected spaces (and vault-level data if this '
          'is the primary) to the remote. Any changes on the remote that '
          'you haven\'t pulled will be overwritten.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Push')),
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
        setState(() => _status = r.summary);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    if (!await _save()) return;
    if (!_tokenStored && _token.text.trim().isEmpty) {
      setState(() => _error = 'Enter a token first');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pull from remote?'),
        content: const Text(
          'This overwrites local files in the selected spaces (and vault-'
          'level data if this is the primary) with the remote version. '
          'A backup of the vault is saved before pulling.\n\n'
          'On web, the backup is stored in the browser\'s local storage '
          'and keeps only the 3 most recent backups.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pull')),
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
        setState(() => _status = r.summary);
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
    final spaces = widget.store.spaces;
    final isNew = widget.existing == null;
    final onlyConfig = widget.store.syncConfigs.length <= 1 && !isNew;

    return EscapeBack(child: Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New repository' : 'Edit repository'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
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
          _section(theme, 'Name'),
          TextField(
            controller: _name,
            enabled: !_busy,
            decoration: const InputDecoration(
              hintText: 'My backup',
              helperText: 'Display name for this repository',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _section(theme, 'Remote'),
          DropdownButtonFormField<SyncProviderKind>(
            value: _provider,
            decoration: const InputDecoration(
              labelText: 'Provider',
              border: OutlineInputBorder(),
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
              labelText: 'Host (optional)',
              hintText: _provider.defaultHost,
              helperText: 'Leave empty for ${_provider.defaultHost}. '
                  'For self-hosted, enter the hostname.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _owner,
            enabled: !_busy,
            decoration: const InputDecoration(
                labelText: 'Owner / group', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repo,
            enabled: !_busy,
            decoration: const InputDecoration(
                labelText: 'Repository', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _branch,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      labelText: 'Branch', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _prefix,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                      labelText: 'Path prefix (optional)',
                      border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section(theme, 'Primary'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set as primary'),
            subtitle: Text(
              _isPrimary
                  ? 'This repo also backs up vault-level data (hooks).'
                  : onlyConfig
                      ? 'The only repository is automatically primary.'
                      : 'Enabling this will demote the current primary.',
            ),
            value: _isPrimary,
            onChanged: _busy || onlyConfig
                ? null
                : (v) => setState(() => _isPrimary = v),
          ),
          const SizedBox(height: 20),
          _section(theme, 'Spaces'),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('All spaces (including future ones)'),
            value: true,
            groupValue: _spaceIds == null,
            onChanged: _busy ? null : (_) => setState(() => _spaceIds = null),
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Selected spaces'),
            value: true,
            groupValue: _spaceIds != null,
            onChanged: _busy ? null : (_) => setState(() => _spaceIds ??= {}),
          ),
          if (_spaceIds != null) ...[
            const SizedBox(height: 6),
            // Local spaces first, remote-only after.
            ..._buildSpaceCheckboxes(theme),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _remoteSpaces == null
                        ? 'Tap "Load remote spaces" to see spaces that exist on the '
                            'remote but haven\'t been pulled yet.'
                        : '${_remoteSpaces!.length} space(s) on the remote. '
                            'Remote-only spaces are marked.',
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
                  label: const Text('Load remote spaces'),
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
                      '$missing space(s) exist on the remote but are not '
                      'selected. They will not be pulled by this config until added.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
          ],
          const SizedBox(height: 20),
          _section(theme, 'Drive offloading'),
          TextField(
            controller: _keepLocal,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Keep on disk (files per space)',
              helperText: 'Newest N files stay on disk; older files are '
                  'offloaded to the remote and fetched on demand. '
                  'Empty = keep everything.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _section(theme, 'Token'),
          if (_tokenStored && !_showTokenInput)
            Row(
              children: [
                const Icon(Icons.lock, size: 16),
                const SizedBox(width: 8),
                const Expanded(child: Text('Token stored')),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _showTokenInput = true),
                  child: const Text('Change'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await widget.store.clearSyncToken(_id);
                          await _loadTokenState();
                          if (mounted) setState(() {});
                        },
                  child: const Text('Clear'),
                ),
              ],
            )
          else
            TextField(
              controller: _token,
              enabled: !_busy,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Personal access token',
                helperText: _provider == SyncProviderKind.github
                    ? 'Create at github.com/settings/tokens with "repo" scope'
                    : 'Create at gitlab.com/-/user_settings/'
                        'personal_access_tokens with "api" scope',
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
                  label: const Text('Verify access'),
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
                  label: const Text('Push to remote'),
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
                  label: const Text('Pull from remote'),
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

  List<Widget> _buildSpaceCheckboxes(ThemeData theme) {
    final localIds = <String>{};
    final localWidgets = <Widget>[];
    for (final s in widget.store.spaces) {
      localIds.add(s.id);
      final checked = _spaceIds!.contains(s.id);
      localWidgets.add(CheckboxListTile(
        contentPadding: const EdgeInsets.only(left: 32, right: 0),
        dense: true,
        value: checked,
        title: Text('${s.icon} ${s.name}'),
        onChanged: _busy
            ? null
            : (v) => setState(() {
                  if (v == true) {
                    _spaceIds!.add(s.id);
                  } else {
                    _spaceIds!.remove(s.id);
                  }
                }),
      ));
    }

    // Remote-only spaces: not present locally. Show display name if we
    // could fetch it, fall back to the bare id otherwise. Sort by name
    // so the list stays stable when spaces have names.
    final remoteOnly = <({String id, String? name})>[];
    if (_remoteSpaces != null) {
      for (final entry in _remoteSpaces!.entries) {
        if (localIds.contains(entry.key)) continue;
        remoteOnly.add((id: entry.key, name: entry.value));
      }
      remoteOnly.sort((a, b) {
        final an = (a.name ?? a.id).toLowerCase();
        final bn = (b.name ?? b.id).toLowerCase();
        return an.compareTo(bn);
      });
    }

    final remoteWidgets = <Widget>[];
    for (final r in remoteOnly) {
      final checked = _spaceIds!.contains(r.id);
      remoteWidgets.add(CheckboxListTile(
        contentPadding: const EdgeInsets.only(left: 32, right: 0),
        dense: true,
        value: checked,
        title: Row(
          children: [
            Expanded(
              child: Text(
                r.name ?? r.id,
                overflow: TextOverflow.ellipsis,
                style: r.name == null
                    ? theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      )
                    : null,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'remote only',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.name != null)
              Text(
                'id: ${r.id}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              'Not on this device yet — will be pulled on next sync',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
        onChanged: _busy
            ? null
            : (v) => setState(() {
                  if (v == true) {
                    _spaceIds!.add(r.id);
                  } else {
                    _spaceIds!.remove(r.id);
                  }
                }),
      ));
    }

    return [...localWidgets, ...remoteWidgets];
  }
}
