import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/bookmarks.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/space_icons.dart';
import '../../l10n/l10n.dart';
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.spacesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_outlined),
            tooltip: l.spacesHooksTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HookListScreen(store: store),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: l.spacesSyncTooltip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SyncScreen(store: store)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: l.spacesImportTooltip,
            onPressed: () => _importFile(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.spacesSettingsTooltip,
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
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final space = store.spaces[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(space.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(space.name),
                        subtitle: Text(_subtitleFor(context, store, space)),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) {
                            if (v == 'stats') {
                              SpaceStatsDialog.show(context, store, space);
                            }
                            if (v == 'edit') _editSpace(context, space);
                            if (v == 'export') {
                              exportSpaceZip(context, store, space);
                            }
                            if (v == 'delete')
                              _confirmDelete(context, space);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'stats',
                                child: Text(l.spacesStatistics)),
                            PopupMenuItem(
                                value: 'edit',
                                child: Text(l.spacesEdit)),
                            PopupMenuItem(
                                value: 'export',
                                child: Text(l.spacesExport)),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text(l.spacesDelete)),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SpaceFeedScreen(
                                store: store, space: space),
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
    final l = context.l10n;
    final result = await showSpaceDialog(
      context,
      initialName: '',
      initialIcon: kSpaceIcons.first,
      title: l.spaceDialogNewTitle,
      confirmLabel: l.commonCreate,
    );
    if (result != null) {
      await store.createSpace(name: result.name, icon: result.icon);
    }
  }

  Future<void> _editSpace(BuildContext context, Space space) async {
    final l = context.l10n;
    final result = await showSpaceDialog(
      context,
      initialName: space.name,
      initialIcon: space.icon,
      title: l.spaceDialogEditTitle,
      confirmLabel: l.commonSave,
    );
    if (result == null) return;
    await store.updateSpace(
      space.id,
      name: result.name,
      icon: result.icon,
    );
  }

  Future<void> _confirmDelete(BuildContext context, Space space) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.spacesDeleteTitle(space.name)),
        content: Text(l.spacesDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (ok == true) await store.deleteSpace(space.id);
  }

  // ── Import file (creates a new space) ──────────────────────────────────

  Future<void> _importFile(BuildContext context) async {
    final l = context.l10n;
    final picked = await pickImportFiles(context);
    if (picked.isEmpty) return;

    final summaries = <String>[];
    final errors = <String>[];
    var ok = 0;
    var failed = 0;
    var cancelled = 0;

    for (final p in picked) {
      final result = await _importOneAsNewSpace(
        context,
        p,
        autoName: picked.length > 1,
      );
      if (result.cancelled) {
        cancelled++;
        continue;
      }
      if (result.error != null) {
        failed++;
        errors.add('${p.name}: ${result.error}');
      } else {
        ok++;
        final s = result.summary;
        if (s != null && s.isNotEmpty) summaries.add(s);
      }
    }

    if (!context.mounted) return;

    if (picked.length == 1 && ok == 0 && failed == 0) return;

    final String message;
    if (picked.length == 1 && ok == 1 && summaries.isNotEmpty) {
      message = summaries.first;
    } else {
      final parts = <String>[];
      if (ok > 0) parts.add(l.spaceImportSummaryOk(ok));
      if (failed > 0) parts.add(l.spaceImportSummaryFailed(failed));
      if (cancelled > 0) parts.add(l.spaceImportSummaryCancelled(cancelled));
      message = parts.isEmpty ? l.spaceImportNothing : parts.join(' · ');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: failed > 0
            ? SnackBarAction(
                label: l.spaceImportDetails,
                onPressed: () => showImportErrors(context, errors),
              )
            : null,
      ),
    );
  }

  Future<({String? summary, String? error, bool cancelled})>
      _importOneAsNewSpace(
    BuildContext context,
    ({Uint8List bytes, String name}) p, {
    required bool autoName,
  }) async {
    final l = context.l10n;
    final lower = p.name.toLowerCase();
    try {
      if (lower.endsWith('.zip')) {
        final id = await store.importSpaceZip(p.bytes);
        final name = store.spaceById(id)?.name ?? id.substring(0, 8);
        return (
          summary: l.spaceImportZipResult(name),
          error: null,
          cancelled: false,
        );
      }
      if (lower.endsWith('.html') || lower.endsWith('.htm')) {
        final text = utf8.decode(p.bytes, allowMalformed: true);
        if (text.trimLeft().startsWith('<!---')) {
          return (
            summary: null,
            error: l.spaceImportSinglePost,
            cancelled: false,
          );
        }
        final file = BookmarkFileParser.parse(text);
        if (file.bookmarks.isEmpty) {
          return (
            summary: null,
            error: l.spaceImportNoBookmarks,
            cancelled: false,
          );
        }

        String name;
        String icon;
        if (autoName) {
          name = (file.title ?? _stripExtension(p.name)).trim();
          if (name.isEmpty) name = l.spaceImportDefaultBookmarksName;
          icon = '📚';
        } else {
          if (!context.mounted) {
            return (summary: null, error: null, cancelled: true);
          }
          final result = await showSpaceDialog(
            context,
            initialName: file.title ?? l.spaceImportDefaultBookmarksName,
            initialIcon: '📚',
            title: l.spaceImportBookmarksDialogTitle,
            confirmLabel: l.commonImport,
          );
          if (result == null) {
            return (summary: null, error: null, cancelled: true);
          }
          name = result.name;
          icon = result.icon;
        }

        final space = await store.importBookmarksAsNewSpace(
          file: file,
          spaceName: name,
          icon: icon,
        );
        final count = store.postsForSpace(space.id).length;
        return (
          summary: l.spaceImportBookmarksResult(count, name),
          error: null,
          cancelled: false,
        );
      }
      return (
        summary: null,
        error: l.spaceImportUnsupported,
        cancelled: false,
      );
    } catch (e) {
      return (summary: null, error: friendlyError(e), cancelled: false);
    }
  }

  String _stripExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? filename : filename.substring(0, dot);
  }

  // ── Subtitle ───────────────────────────────────────────────────────────

  String _subtitleFor(
      BuildContext context, VaultStore store, Space space) {
    final l = context.l10n;
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
    if (notes > 0) parts.add(l.spacesCountNotes(notes));
    if (bookmarks > 0) parts.add(l.spacesCountBookmarks(bookmarks));
    if (replies > 0) parts.add(l.spacesCountReplies(replies));
    if (files.isNotEmpty) parts.add(l.spacesCountFiles(files.length));
    if (parts.isEmpty) return l.spacesEmptyLabel;
    return parts.join(' · ');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(l.spacesEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l.spacesEmptyHint,
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
