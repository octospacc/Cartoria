import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/sync/sync_config.dart';
import '../../data/sync/sync_provider.dart';
import '../../data/store.dart';

class SyncScreen extends StatefulWidget {
  final VaultStore store;
  const SyncScreen({super.key, required this.store});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late SyncProviderKind _provider;
  late TextEditingController _owner;
  late TextEditingController _repo;
  late TextEditingController _branch;
  late TextEditingController _prefix;
  late TextEditingController _token;

  bool _tokenStored = false;
  bool _showTokenInput = false;
  bool _busy = false;
  String? _status;
  String? _error;
  SyncProgress? _progress;

  @override
  void initState() {
    super.initState();
    final c = widget.store.syncConfig;
    _provider = c?.provider ?? SyncProviderKind.github;
    _owner = TextEditingController(text: c?.owner ?? '');
    _repo = TextEditingController(text: c?.repo ?? '');
    _branch = TextEditingController(text: c?.branch ?? 'main');
    _prefix = TextEditingController(text: c?.pathPrefix ?? '');
    _token = TextEditingController();
    _loadTokenState();
  }

  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _branch.dispose();
    _prefix.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _loadTokenState() async {
    final token = await widget.store.loadSyncToken();
    if (!mounted) return;
    setState(() {
      _tokenStored = token != null && token.isNotEmpty;
      _showTokenInput = !_tokenStored;
    });
  }

  Future<void> _saveConfig() async {
    final owner = _owner.text.trim();
    final repo = _repo.text.trim();
    final branch = _branch.text.trim();
    if (owner.isEmpty || repo.isEmpty) {
      setState(() => _error = 'Owner and repo are required');
      return;
    }
    final existing = widget.store.syncConfig;
    final config = SyncConfig(
      provider: _provider,
      owner: owner,
      repo: repo,
      branch: branch.isEmpty ? 'main' : branch,
      pathPrefix: _prefix.text.trim(),
      lastSyncedAt: existing?.lastSyncedAt,
      lastCommitSha: existing?.lastCommitSha,
    );
    await widget.store.saveSyncConfig(config);
    if (_token.text.trim().isNotEmpty) {
      await widget.store.saveSyncToken(_token.text.trim());
      _token.clear();
      await _loadTokenState();
    }
    if (!mounted) return;
    setState(() => _status = 'Configuration saved');
  }

  Future<void> _verify() async {
    await _saveConfig();
    if (!mounted) return;
    if (!_tokenStored) {
      setState(() => _error = 'Enter a token first');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await widget.store.verifySyncAccess();
      if (!mounted) return;
      setState(() => _status = 'Access verified');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _push() async {
    await _saveConfig();
    if (!mounted) return;
    if (!_tokenStored) {
      setState(() => _error = 'Enter a token first');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push to remote?'),
        content: const Text(
          'This uploads your local vault to the remote and overwrites any '
          'changes there that you haven\'t pulled. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Push'),
          ),
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
      final r = await widget.store.syncPush(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _status = 'Pushed ${r.pushed} file(s), deleted ${r.deleted}'
            '${r.skippedLarge > 0 ? ", skipped ${r.skippedLarge} large" : ""}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    await _saveConfig();
    if (!mounted) return;
    if (!_tokenStored) {
      setState(() => _error = 'Enter a token first');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pull from remote?'),
        content: const Text(
          'This overwrites your local vault with the remote version. '
          'A backup of the current vault is saved automatically before '
          'pulling. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pull'),
          ),
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
      final r = await widget.store.syncPull(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _status = 'Pulled ${r.pulled} file(s), deleted ${r.deleted}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = widget.store.syncConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (config?.lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Last synced: ${config!.lastSyncedAt!.toLocal()}'
                '${config.lastCommitSha != null ? "\nCommit: ${config.lastCommitSha!.substring(0, 7)}" : ""}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          _section(theme, 'Remote'),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<SyncProviderKind>(
                  value: _provider,
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(),
                  ),
                  items: SyncProviderKind.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.label),
                          ))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _provider = v ?? _provider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _owner,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Owner / group',
              hintText: 'myuser',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repo,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Repository',
              hintText: 'myvault',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _branch,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Branch',
              hintText: 'main',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prefix,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Path prefix (optional)',
              hintText: 'vault/',
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
                          await widget.store.clearSyncToken();
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
                helper: _provider == SyncProviderKind.github
                    ? const _HelperLink(
                        href: 'https://github.com/settings/tokens',
                        prefix: 'Create at ',
                        suffix: ' with "repo" scope',
                      )
                    : const _HelperLink(
                        href: 'https://gitlab.com/-/user_settings/personal_access_tokens',
                        prefix: 'Create at ',
                        suffix: ' with "api" scope',
                      ),
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
              Text(
                _progress!.message ?? '',
                style: theme.textTheme.bodySmall,
              ),
            ] else
              const LinearProgressIndicator(),
          ],
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _status!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
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
            ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: theme.textTheme.titleSmall),
      );
}

class _HelperLink extends StatefulWidget {
  final String href;
  final String prefix;
  final String suffix;

  const _HelperLink({
    required this.href,
    required this.prefix,
    this.suffix = '',
  });

  @override
  State<_HelperLink> createState() => _HelperLinkState();
}

class _HelperLinkState extends State<_HelperLink> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()..onTap = _open;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final uri = Uri.parse(widget.href);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${widget.href}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText =
        widget.href.replaceFirst(RegExp(r'^https?://'), '');
    return Text.rich(
      TextSpan(
        text: widget.prefix,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(
            text: displayText,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: _recognizer,
          ),
          if (widget.suffix.isNotEmpty) TextSpan(text: widget.suffix),
        ],
      ),
    );
  }
}