import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/bookmarks.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/space_icons.dart';
import '../../util/json_format.dart';
import '../bookmark_import_helpers.dart';
import '../space_actions.dart';
import '../space_dialogs.dart';
import '../widgets/space_stats_dialog.dart';
import '../widgets/app_footer.dart';
import 'hooks_list.dart';
import 'space_feed.dart';
import 'sync_screen.dart';
import 'settings_screen.dart';

class SpaceListScreen extends StatelessWidget {
  final VaultStore store;
  const SpaceListScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_outlined),
            tooltip: 'Hooks',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HookListScreen(store: store),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SyncScreen(store: store)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            // "New from file" rather than "Import": the file creates a new
            // space, it does not add content to an existing one. The
            // per-space "Import…" action lives inside each space's menu.
            tooltip: 'New space from file…',
            onPressed: () => _importFile(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(store: store)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: store.spaces.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: store.spaces.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final space = store.spaces[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(space.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(space.name),
                        subtitle: Text(_subtitleFor(store, space)),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) {
                            if (v == 'stats') {
                              SpaceStatsDialog.show(context, store, space);
                            }
                            if (v == 'edit') _editSpace(context, space);
                            if (v == 'export')
                              exportSpaceZip(context, store, space);
                            if (v == 'delete') _confirmDelete(context, space);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'stats', child: Text('Statistics')),
                            PopupMenuItem(
                                value: 'edit', child: Text('Edit space…')),
                            PopupMenuItem(
                                value: 'export', child: Text('Export space…')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete space…')),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SpaceFeedScreen(store: store, space: space),
                          ),
                        ),
                        onLongPress: () => _confirmDelete(context, space),
                      );
                    },
                  ),
          ),
          const AppFooter(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newSpace(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Create / edit / delete ─────────────────────────────────────────────

  Future<void> _newSpace(BuildContext context) async {
    final result = await showSpaceDialog(
      context,
      initialName: '',
      initialIcon: kSpaceIcons.first,
    );
    if (result != null) {
      await store.createSpace(name: result.name, icon: result.icon);
    }
  }

  Future<void> _editSpace(BuildContext context, Space space) async {
    final result = await showSpaceDialog(
      context,
      initialName: space.name,
      initialIcon: space.icon,
      title: 'Edit space',
      confirmLabel: 'Save',
    );
    if (result == null) return;
    await store.updateSpace(
      space.id,
      name: result.name,
      icon: result.icon,
    );
  }

  Future<void> _confirmDelete(BuildContext context, Space space) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${space.name}"?'),
        content: const Text(
            'This removes every post and file in this space. Cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await store.deleteSpace(space.id);
  }

  // ── Import file (creates a new space) ──────────────────────────────────

  Future<void> _importFile(BuildContext context) async {
    final picked = await pickImportFile(context);
    if (picked == null) return;
    final lower = picked.name.toLowerCase();
    if (lower.endsWith('.zip')) {
      await _importZipBytes(context, picked.bytes);
    } else if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      final text = utf8.decode(picked.bytes, allowMalformed: true);
      if (text.trimLeft().startsWith('<!---')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This is a single post file. Open a space and use '
                'Import… to add it there.',
              ),
            ),
          );
        }
        return;
      }
      await _importBookmarksBytes(context, picked.bytes);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported file type')),
      );
    }
  }

  Future<void> _importZipBytes(BuildContext context, Uint8List bytes) async {
    try {
      final id = await store.importSpaceZip(bytes);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported space ${id.substring(0, 8)}…')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _importBookmarksBytes(
      BuildContext context, Uint8List bytes) async {
    BookmarkFile file;
    try {
      file = BookmarkFileParser.parse(
        utf8.decode(bytes, allowMalformed: true),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not parse file: $e')),
        );
      }
      return;
    }
    if (file.bookmarks.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No bookmarks found in file')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final result = await showSpaceDialog(
      context,
      initialName: file.title ?? 'Imported Bookmarks',
      initialIcon: '📚',
      title: 'Import bookmarks',
      confirmLabel: 'Import',
    );
    if (result == null) return;

    try {
      final space = await store.importBookmarksAsNewSpace(
        file: file,
        spaceName: result.name,
        icon: result.icon,
      );
      if (!context.mounted) return;
      final count = store.postsForSpace(space.id).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count into "${space.name}"')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  // ── Subtitle ───────────────────────────────────────────────────────────

  String _subtitleFor(VaultStore store, Space space) {
    final posts = store.postsForSpace(space.id);
    final files = store.filesForSpace(space.id);

    int notes = 0;
    int bookmarks = 0;
    int replies = 0;
    for (final p in posts) {
      if (p.parentId != null) replies++;
      if (p.kind == PostKind.bookmark) {
        bookmarks++;
      } else {
        notes++;
      }
    }

    final parts = <String>[];
    if (notes > 0) {
      parts.add('$notes ${notes == 1 ? "note" : "notes"}');
    }
    if (bookmarks > 0) {
      parts.add('$bookmarks ${bookmarks == 1 ? "bookmark" : "bookmarks"}');
    }
    if (replies > 0) {
      parts.add('$replies ${replies == 1 ? "reply" : "replies"}');
    }
    if (files.isNotEmpty) {
      parts.add('${files.length} ${files.length == 1 ? "file" : "files"}');
    }
    if (parts.isEmpty) return 'Empty';
    return parts.join(' · ');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('No spaces yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first space, or import from a file '
              'using the icon at the top.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
