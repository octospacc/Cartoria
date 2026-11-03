import 'package:flutter/material.dart';

import '../../data/hooks.dart';
import '../../data/store.dart';
import 'hook_edit.dart';

class HookListScreen extends StatelessWidget {
  final VaultStore store;
  const HookListScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final hooks = store.hooks;
        return Scaffold(
          appBar: AppBar(title: const Text('Hooks')),
          body: hooks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hooks yet.\nA hook runs an HTTP request when a post '
                      'is created or edited.',
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
                      subtitle: Text(_summary(h)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HookEditScreen(store: store, existing: h),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
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
    );
  }

  String _summary(Hook h) {
    final triggers = h.triggers.map((t) => t.name).join(' + ');
    final spaces = h.spaceIds.isEmpty
        ? 'all spaces'
        : '${h.spaceIds.length} space${h.spaceIds.length == 1 ? "" : "s"}';
    return '${h.method} · $triggers · $spaces · key: ${h.key}';
  }

  Future<void> _delete(BuildContext context, Hook hook) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${hook.name}"?'),
        content: const Text(
            'Posts keep their last hook results, but the hook will no '
            'longer fire.'),
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
    if (ok == true) await store.deleteHook(hook.id);
  }
}