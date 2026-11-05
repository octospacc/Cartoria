import 'dart:typed_data';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../bookmark_import_helpers.dart';
import '../../data/bookmarks.dart';
import '../../data/models.dart';
import '../../data/space_icons.dart';
import '../../data/store.dart';
import '../../platform/file_read.dart';
import '../widgets/space_stats_dialog.dart';
import 'hooks_list.dart';
import 'space_feed.dart';
import 'sync_screen.dart';

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
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import',
            onPressed: () => _importFile(context),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: store.spaces.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final space = store.spaces[i];
          return ListTile(
            leading: CircleAvatar(
              child: Text(space.icon, style: const TextStyle(fontSize: 20)),
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
                if (v == 'delete') _confirmDelete(context, space);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'stats', child: Text('Statistics')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete space')),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SpaceFeedScreen(store: store, space: space),
              ),
            ),
            onLongPress: () => _confirmDelete(context, space),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newSpace(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Create / edit / delete ─────────────────────────────────────────────

  Future<void> _newSpace(BuildContext context) async {
    final result = await _showCreateSpaceDialog(
      context,
      initialName: '',
      initialIcon: kSpaceIcons.first,
    );
    if (result != null) {
      await store.createSpace(name: result.name, icon: result.icon);
    }
  }

  Future<void> _editSpace(BuildContext context, Space space) async {
    final result = await _showCreateSpaceDialog(
      context,
      initialName: space.name,
      initialIcon: space.icon,
      title: 'Edit space',
      confirmLabel: 'Save',
    );
    if (result != null) {
      await store.updateSpace(
        space.id,
        name: result.name,
        icon: result.icon,
      );
    }
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

Future<void> _importFile(BuildContext context) async {
  final picked = await pickImportFile(context);
  if (picked == null) return;
  final lower = picked.name.toLowerCase();
  if (lower.endsWith('.zip')) {
    await _importZipBytes(context, picked.bytes);
  } else if (lower.endsWith('.html') || lower.endsWith('.htm')) {
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

  final result = await _showCreateSpaceDialog(
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

  // ── Shared: new-space dialog ───────────────────────────────────────────

  Future<({String name, String icon})?> _showCreateSpaceDialog(
    BuildContext context, {
    required String initialName,
    required String initialIcon,
    String title = 'New space',
    String confirmLabel = 'Create',
  }) async {
    final c = TextEditingController(text: initialName);
    var icon = initialIcon;

    // 560px holds ~11 chips per row; clamp to 90% of screen so phones
    // still fit without horizontal overflow.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxAllowed = screenWidth * 0.9;
    final dialogWidth = 560.0 < maxAllowed ? 560.0 : maxAllowed;

    final result = await showDialog<({String name, String icon})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            scrollable: true,
            title: Text(title),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: c,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kSpaceIcons.map((i) {
                      final selected = icon == i;
                      return ChoiceChip(
                        label: Text(
                          i,
                          style: const TextStyle(fontSize: 20),
                        ),
                        selected: selected,
                        showCheckmark: false,
                        avatar: selected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: theme.colorScheme.onSecondaryContainer,
                              )
                            : const SizedBox(width: 18, height: 18),
                        onSelected: (_) => setS(() => icon = i),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = c.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx, (name: name, icon: icon));
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      ),
    );
    c.dispose();
    return result;
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
