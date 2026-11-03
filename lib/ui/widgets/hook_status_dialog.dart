import 'package:flutter/material.dart';

import '../../data/hooks.dart';
import '../../data/models.dart';
import '../../data/store.dart';

/// Read-only inspector for the hook results stored on [post].
///
/// Non-destructive by design: the user can look at what each hook sent,
/// what came back, and — crucially — which JSON path a follow-up hook
/// (e.g. Telegram's `editMessageText`) will dereference via
/// `{{previous.<key>.json.<path>}}`.
Future<void> showHookStatusDialog(
  BuildContext context,
  Post post,
  VaultStore store,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hook status'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: post.hookState.entries
              .map((e) => _HookStateBlock(
                    hookKey: e.key,
                    state: e.value,
                    hookName: _hookNameFor(store, e.key),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _hookNameFor(VaultStore store, String key) {
  for (final Hook h in store.hooks) {
    if (h.key == key) return h.name;
  }
  return key;
}

class _HookStateBlock extends StatelessWidget {
  final String hookKey;
  final PostHookState state;
  final String hookName;

  const _HookStateBlock({
    required this.hookKey,
    required this.state,
    required this.hookName,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hookName,
            style: theme.textTheme.titleSmall,
          ),
          Text('key: $hookKey', style: theme.textTheme.bodySmall),
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
              style: theme.textTheme.bodySmall,
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