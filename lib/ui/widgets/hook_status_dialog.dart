import 'package:flutter/material.dart';

import '../../data/hooks.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../util/hook_outcome.dart';

/// Read-only inspector for the hook results stored on [post], with a
/// per-hook re-run button. Retries are useful after failures (bad token,
/// transient network error, server temporarily down) and also after
/// successful runs (e.g. re-send to Telegram after editing the chat on
/// their side).
Future<void> showHookStatusDialog(
  BuildContext context,
  Post post,
  VaultStore store,
  String spaceId,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _HookStatusDialog(
      post: post,
      store: store,
      spaceId: spaceId,
    ),
  );
}

class _HookStatusDialog extends StatefulWidget {
  final Post post;
  final VaultStore store;
  final String spaceId;

  const _HookStatusDialog({
    required this.post,
    required this.store,
    required this.spaceId,
  });

  @override
  State<_HookStatusDialog> createState() => _HookStatusDialogState();
}

class _HookStatusDialogState extends State<_HookStatusDialog> {
  /// Hook keys with a retry in flight, started from this dialog. Kept
  /// separate from the store's `_activeHookRuns` so the dialog's buttons
  /// disable as soon as the user taps, even before `notifyListeners()`
  /// reaches the dialog.
  final Set<String> _retrying = {};

  Future<void> _retry(String hookKey) async {
    setState(() => _retrying.add(hookKey));
    try {
      await widget.store.retryHook(
        widget.spaceId,
        widget.post.id,
        hookKey,
      );
    } finally {
      if (mounted) setState(() => _retrying.remove(hookKey));
    }
  }

  Future<void> _retryAllFailed() async {
    final post = _resolveCurrentPost();
    if (post == null) return;

    final failedKeys = <String>[
      for (final e in post.hookState.entries)
        if (!_retrying.contains(e.key) && hookStateFailed(e.value)) e.key,
    ];
    if (failedKeys.isEmpty) return;

    setState(() => _retrying.addAll(failedKeys));
    try {
      for (final key in failedKeys) {
        await widget.store.retryHook(
          widget.spaceId,
          widget.post.id,
          key,
        );
        if (!mounted) return;
        setState(() => _retrying.remove(key));
      }
    } finally {
      if (mounted) setState(_retrying.clear);
    }
  }

  Post? _resolveCurrentPost() {
    for (final p in widget.store.postsForSpace(widget.spaceId)) {
      if (p.id == widget.post.id) return p;
    }
    return widget.post;
  }

  String _hookNameFor(String key) {
    for (final Hook h in widget.store.hooks) {
      if (h.key == key) return h.name;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    // Re-read from the store on every build so retry results appear
    // without needing to close and reopen the dialog.
    final post = _resolveCurrentPost() ?? widget.post;

    final entries = post.hookState.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final anyFailed = entries.any((e) => hookStateFailed(e.value));
    final failedCount = entries.where((e) => hookStateFailed(e.value)).length;

    return AlertDialog(
      title: const Text('Hook status'),
      content: SizedBox(
        width: 520,
        child: entries.isEmpty
            ? const Text('No hook results yet.')
            : ListView(
                shrinkWrap: true,
                children: entries.map((e) {
                  final key = e.key;
                  final state = e.value;
                  final isRunning = _retrying.contains(key) ||
                      widget.store.hasActiveHooks(post.id);
                  final failed = hookStateFailed(state);
                  return _HookStateBlock(
                    hookKey: key,
                    state: state,
                    hookName: _hookNameFor(key),
                    hookExists: widget.store.hooks.any((h) => h.key == key),
                    isRunning: isRunning,
                    onRetry: isRunning ? null : () => _retry(key),
                  );
                }).toList(),
              ),
      ),
      actions: [
        if (anyFailed && failedCount > 1)
          TextButton.icon(
            onPressed: _retrying.isEmpty ? _retryAllFailed : null,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text('Re-run all failed ($failedCount)'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _HookStateBlock extends StatelessWidget {
  final String hookKey;
  final PostHookState state;
  final String hookName;
  final bool hookExists;
  final bool isRunning;
  final VoidCallback? onRetry;

  const _HookStateBlock({
    required this.hookKey,
    required this.state,
    required this.hookName,
    required this.hookExists,
    required this.isRunning,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
    );
    final body = state.lastBody;
    final truncatedBody = body == null || body.isEmpty
        ? null
        : (body.length > 500 ? '${body.substring(0, 500)}…' : body);

    final failed = hookStateFailed(state);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      hookName,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      isRunning: isRunning,
                      failed: failed,
                    ),
                  ],
                ),
              ),
              if (isRunning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hookExists)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: failed ? 'Re-run' : 'Re-run',
                  onPressed: onRetry,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          Text('key: $hookKey', style: theme.textTheme.bodySmall),
          if (!hookExists)
            Text(
              'This hook no longer exists in the vault.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontStyle: FontStyle.italic,
              ),
            ),
          Text(
            'fired: ${state.lastFiredAt.toLocal()}',
            style: theme.textTheme.bodySmall,
          ),
          if (state.lastError != null)
            Text(
              'error: ${state.lastError}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (state.lastStatus != null)
            Text(
              'status: ${state.lastStatus}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: failed ? theme.colorScheme.error : null,
              ),
            ),
          if (truncatedBody != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(truncatedBody, style: mono),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isRunning;
  final bool failed;

  const _StatusBadge({required this.isRunning, required this.failed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = isRunning
        ? (theme.colorScheme.onSurfaceVariant, 'Running')
        : failed
            ? (theme.colorScheme.error, 'Failed')
            : (Colors.green.shade600, 'Success');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}