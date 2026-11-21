import 'package:flutter/material.dart';

import '../../data/hooks.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../util/hook_outcome.dart';

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
  final Set<String> _running = {};
  bool _runningAll = false;

  Post? _currentPost() {
    for (final p in widget.store.postsForSpace(widget.spaceId)) {
      if (p.id == widget.post.id) return p;
    }
    return widget.post;
  }

  Future<void> _run(String hookKey) async {
    setState(() => _running.add(hookKey));
    try {
      await widget.store.retryHook(
        widget.spaceId, widget.post.id, hookKey);
    } finally {
      if (mounted) setState(() => _running.remove(hookKey));
    }
  }

  Future<void> _runAll() async {
    final post = _currentPost();
    if (post == null) return;
    final applicable =
        widget.store.applicableHooksFor(widget.spaceId, post.id);
    if (applicable.isEmpty) return;

    setState(() => _runningAll = true);
    try {
      for (final h in applicable) {
        if (!mounted) return;
        setState(() => _running.add(h.key));
        await widget.store.retryHook(widget.spaceId, post.id, h.key);
        if (!mounted) return;
        setState(() => _running.remove(h.key));
      }
    } finally {
      if (mounted) setState(() {
        _runningAll = false;
        _running.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _currentPost() ?? widget.post;
    final applicable =
        widget.store.applicableHooksFor(widget.spaceId, post.id);
    final applicableKeys = {for (final h in applicable) h.key};

    final orphaned = post.hookState.entries
        .where((e) => !applicableKeys.contains(e.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final anyRunning =
        _running.isNotEmpty || _runningAll ||
        widget.store.hasActiveHooks(post.id);

    final theme = Theme.of(context);
    final l = context.l10n;

    return AlertDialog(
      title: Text(l.hookStatusTitle),
      content: SizedBox(
        width: 520,
        child: (applicable.isEmpty && orphaned.isEmpty)
            ? Text(l.hookStatusNone)
            : ListView(
                shrinkWrap: true,
                children: [
                  if (applicable.isNotEmpty) ...[
                    _SectionHeader(
                      title: l.hookStatusApplicable(applicable.length),
                      trailing: applicable.length > 1
                          ? TextButton.icon(
                              onPressed: anyRunning ? null : _runAll,
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: Text(l.hookStatusRunAll),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    for (final h in applicable)
                      _HookRow(
                        hook: h,
                        state: post.hookState[h.key],
                        isRunning: _running.contains(h.key),
                        enabled: !anyRunning,
                        onRun: () => _run(h.key),
                      ),
                  ],
                  if (orphaned.isNotEmpty) ...[
                    if (applicable.isNotEmpty) const Divider(height: 24),
                    _SectionHeader(title: l.hookStatusPast),
                    const SizedBox(height: 4),
                    for (final e in orphaned)
                      _HookRow(
                        hook: null,
                        hookKeyFallback: e.key,
                        state: e.value,
                        isRunning: false,
                        enabled: false,
                        onRun: null,
                      ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    l.hookStatusHelper,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonClose),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HookRow extends StatelessWidget {
  final Hook? hook;
  final String? hookKeyFallback;
  final PostHookState? state;
  final bool isRunning;
  final bool enabled;
  final VoidCallback? onRun;

  const _HookRow({
    required this.hook,
    this.hookKeyFallback,
    required this.state,
    required this.isRunning,
    required this.enabled,
    required this.onRun,
  });

  String get _key => hook?.key ?? hookKeyFallback ?? '?';
  String get _name => hook?.name ?? _key;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace', fontSize: 11);
    final body = state?.lastBody;
    final truncatedBody = body == null || body.isEmpty
        ? null
        : (body.length > 500 ? '${body.substring(0, 500)}…' : body);

    final failed = state != null && hookStateFailed(state!);
    final never = state == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _name,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isRunning)
                      _Badge(
                        color: theme.colorScheme.onSurfaceVariant,
                        label: l.hookStatusRunning,
                      )
                    else if (never)
                      _Badge(
                        color: theme.colorScheme.onSurfaceVariant,
                        label: l.hookStatusNeverFired,
                      )
                    else
                      _Badge(
                        color: failed
                            ? theme.colorScheme.error
                            : Colors.green.shade600,
                        label: failed
                            ? l.hookStatusFailed
                            : l.hookStatusSuccess,
                      ),
                  ],
                ),
              ),
              if (onRun != null) ...[
                if (isRunning)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: enabled ? onRun : null,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text(l.hookStatusRun),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ],
          ),
          Text(l.hookStatusKey(_key), style: theme.textTheme.bodySmall),
          if (hook == null)
            Text(
              l.hookStatusOrphan,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (state != null) ...[
            Text(
              l.hookStatusFired(state!.lastFiredAt.toLocal().toString()),
              style: theme.textTheme.bodySmall,
            ),
            if (state!.lastError != null)
              Text(
                l.hookStatusError(state!.lastError!),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              )
            else if (state!.lastStatus != null)
              Text(
                l.hookStatusStatus(state!.lastStatus!.toString()),
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
          ],
          const Divider(height: 20),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final String label;

  const _Badge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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