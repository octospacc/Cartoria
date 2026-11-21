import 'package:flutter/material.dart';

import '../../data/hooks.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../widgets/escape_back.dart';
import 'hook_edit.dart';

class HookListScreen extends StatelessWidget {
  final VaultStore store;
  const HookListScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EscapeBack(
        child: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final hooks = store.hooks;
        return Scaffold(
          appBar: AppBar(title: Text(l.hooksTitle)),
          body: hooks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.hooksEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: hooks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final h = hooks[i];
                    return ListTile(
                      leading: Switch(
                        value: h.enabled,
                        onChanged: (v) => store.saveHook(h.withEnabled(v)),
                      ),
                      title: Text(h.name),
                      subtitle: Text(_summary(context, h)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HookEditScreen(store: store, existing: h),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l.commonDelete,
                        onPressed: () => _delete(context, h),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HookEditScreen(store: store),
              ),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    ));
  }

  String _summary(BuildContext context, Hook h) {
    final l = context.l10n;
    final triggers = h.triggers
        .map((t) => t == HookTrigger.create
            ? l.hookTriggerCreate
            : l.hookTriggerEdit)
        .join(' + ');
    final spaces = h.spaceIds.isEmpty
        ? l.hooksSpacesAll
        : l.hooksSpacesCount(h.spaceIds.length);
    return l.hooksSummary(
      l.hooksRulesCount(h.rules.length),
      triggers,
      spaces,
      h.key,
    );
  }

  Future<void> _delete(BuildContext context, Hook hook) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.hooksDeleteTitle(hook.name)),
        content: Text(l.hooksDeleteBody),
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
    if (ok == true) await store.deleteHook(hook.id);
  }
}