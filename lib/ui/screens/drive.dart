import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../platform/file_save.dart';
import '../../platform/clipboard_files.dart';
import '../../util/file_category.dart';
import '../widgets/escape_back.dart';
import '../widgets/file_thumbnail.dart';
import '../widgets/file_usage_sheet.dart';
import 'drive/file_viewer.dart';

class DriveScreen extends StatefulWidget {
  final VaultStore store;
  final Space space;

  /// Optional callback used by the "Show posts using this file…" sheet
  /// when the user taps a post. Caller (usually the space feed) is
  /// expected to pop the drive, then scroll to the post. Null disables
  /// navigation from the sheet — posts still list, just not tappable.
  final void Function(String postId)? onViewPostInFeed;

  const DriveScreen({
    super.key,
    required this.store,
    required this.space,
    this.onViewPostInFeed,
  });

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  /// Resolves the current version of this space from the store on every
  /// read. `widget.space` is a snapshot taken at navigation time, so
  /// without this the drive title keeps showing the old name/icon after
  /// the space is edited elsewhere.
  Space get _space => widget.store.spaceById(widget.space.id) ?? widget.space;

  bool _grid = true;
  bool _selectionMode = false;
  final Set<String> _selectedFileIds = {};

  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _selectionMode = true;
      if (initialId != null) _selectedFileIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedFileIds.clear();
    });
  }

  void _toggleSelection(String fileId) {
    setState(() {
      if (_selectedFileIds.contains(fileId)) {
        _selectedFileIds.remove(fileId);
      } else {
        _selectedFileIds.add(fileId);
      }
    });
  }

  Future<void> _deleteSelectedFiles() async {
    final selected = Set<String>.from(_selectedFileIds);
    if (selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete ${selected.length} '
          '${selected.length == 1 ? "file" : "files"}?',
        ),
        content: const Text(
          'Posts that reference these files will lose the attachments. '
          'This cannot be undone.',
        ),
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
    if (ok != true) return;

    await widget.store.deleteFiles(widget.space.id, selected);
    if (mounted) _exitSelectionMode();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final files = await readClipboardFiles();
      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No image or file found in clipboard. On web, try pasting '
                'into a composer.',
              ),
            ),
          );
        }
        return;
      }
      var added = 0;
      for (final f in files) {
        try {
          await widget.store.addFileFromBytes(
            spaceId: widget.space.id,
            bytes: f.bytes,
            name: f.name,
          );
          added++;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Paste failed: $e')),
            );
          }
        }
      }
      if (mounted && added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $added file${added == 1 ? "" : "s"} from clipboard.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paste failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EscapeBack(
        onEscape: _selectionMode || _searchActive
            ? () {
                if (_selectionMode) {
                  _exitSelectionMode();
                } else {
                  setState(() {
                    _searchCtrl.clear();
                    _searchActive = false;
                  });
                }
              }
            : null,
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final allFiles = widget.store.filesForSpace(widget.space.id);
            final offloadedIds = widget.store.offloadedFileIds(widget.space.id);
            final used = widget.store.usedFileIds(widget.space.id);

            // Filter by filename substring when search is active.
            final query = _searchActive ? _searchCtrl.text.trim() : '';
            final files = query.isEmpty
                ? allFiles
                : allFiles
                    .where((f) =>
                        f.name.toLowerCase().contains(query.toLowerCase()))
                    .toList();

            final offloadedCount =
                files.where((f) => offloadedIds.contains(f.id)).length;
            final unusedCount = files.where((f) => !used.contains(f.id)).length;

            return Scaffold(
              appBar:
                  _buildAppBar(context, allFiles, used, files.length, query),
              body: allFiles.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No files yet.\nUpload one here, or attach from a post.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : files.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No files match "$query".',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Row(
                                children: [
                                  Icon(
                                    _searchActive
                                        ? Icons.search
                                        : Icons.folder_outlined,
                                    size: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _driveSummary(files.length,
                                          offloadedCount, unusedCount),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _grid
                                  ? _buildGrid(files, offloadedIds, used)
                                  : _buildList(files, offloadedIds, used),
                            ),
                          ],
                        ),
              floatingActionButton: _selectionMode
                  ? null
                  : FloatingActionButton(
                      onPressed: () => _upload(context),
                      child: const Icon(Icons.add),
                    ),
            );
          },
        ));
  }

  /// "N files" always, then "M offloaded" and "K unused" only when
  /// non-zero. `unused` counts any file not referenced by a post,
  /// regardless of state (on-disk, offloaded, or missing) — so it's a
  /// direct "how much can I clean up" number.
  String _driveSummary(int total, int offloaded, int unused) {
    final parts = <String>[
      '$total ${total == 1 ? "file" : "files"}',
      if (offloaded > 0) '$offloaded offloaded',
      if (unused > 0) '$unused unused',
    ];
    return parts.join(' · ');
  }

  Widget _buildGrid(
    List<DriveFile> files,
    Set<String> offloadedIds,
    Set<String> used,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      // Do not keep off-screen tiles alive. `FileThumbnail`'s byte cache
      // makes re-creating them cheap (a Map lookup), so freeing the
      // widget's state on scroll-back costs nothing visually and eliminates
      // the accumulated memory of hundreds of retained tile states.
      addAutomaticKeepAlives: false,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        return _GridTile(
          key: ValueKey(f.id),
          store: widget.store,
          space: widget.space,
          file: f,
          isUsed: used.contains(f.id),
          isOffloaded: offloadedIds.contains(f.id),
          selectionMode: _selectionMode,
          isSelected: _selectedFileIds.contains(f.id),
          onTap: _selectionMode
              ? () => _toggleSelection(f.id)
              : () => _openViewer(f),
          onLongPress: _selectionMode ? null : () => _enterSelectionMode(f.id),
          onMenuAction: (v) => _handleMenu(v, f),
        );
      },
    );
  }

  Widget _buildList(
    List<DriveFile> files,
    Set<String> offloadedIds,
    Set<String> used,
  ) {
    final theme = Theme.of(context);
    return ListView.separated(
      addAutomaticKeepAlives: false,
      itemCount: files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final f = files[i];
        final selected = _selectedFileIds.contains(f.id);
        final isUsed = used.contains(f.id);
        final isOffloaded = offloadedIds.contains(f.id);
        return ListTile(
          selected: _selectionMode && selected,
          selectedTileColor:
              theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
          leading: _selectionMode
              ? Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                )
              : Icon(iconForCategory(categoryFor(f.name))),
          title: Text(f.name, overflow: TextOverflow.ellipsis),
          subtitle: Row(
            children: [
              Text('${(f.sizeBytes / 1024).toStringAsFixed(1)} KB'),
              const SizedBox(width: 8),
              Icon(
                isUsed ? Icons.link : Icons.link_off,
                size: 12,
                color: isUsed
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 3),
              Text(
                isUsed ? 'used' : 'unused',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isUsed
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
              if (f.isMissing) ...[
                const SizedBox(width: 8),
                Icon(Icons.cloud_off, size: 12, color: theme.colorScheme.error),
                const SizedBox(width: 3),
                Text('missing',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ] else if (isOffloaded) ...[
                const SizedBox(width: 8),
                Icon(Icons.cloud,
                    size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('remote',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
          onTap: _selectionMode
              ? () => _toggleSelection(f.id)
              : () => _openViewer(f),
          onLongPress: _selectionMode ? null : () => _enterSelectionMode(f.id),
          trailing: _selectionMode
              ? null
              : PopupMenuButton<String>(
                  onSelected: (v) => _handleMenu(v, f),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'open', child: Text('Open')),
                    if (used.contains(f.id))
                      const PopupMenuItem(
                          value: 'usage',
                          child: Text('Show posts using this file…')),
                    const PopupMenuItem(
                        value: 'share', child: Text('Share / download')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _handleMenu(String action, DriveFile f) async {
    switch (action) {
      case 'open':
        await _openViewer(f);
        break;
      case 'usage':
        await _showFileUsage(f);
        break;
      case 'share':
        await widget.store.ensureFileLocal(widget.space.id, f.id);
        final bytes = await widget.store.readFileBytes(widget.space.id, f.id);
        await saveOrShareFile(bytes, f.name);
        break;
      case 'delete':
        await _confirmDelete(f);
        break;
    }
  }

  Future<void> _openViewer(DriveFile f) async {
    if (f.isMissing) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('"${f.name}" is missing'),
          content: const Text(
            'This file is referenced by one or more posts, but its content '
            'isn\'t stored anywhere on this device or the sync remote.\n\n'
            'You can restore it by re-importing the full export it came '
            'from, pulling from the sync remote if it still has the file, '
            'or by picking a replacement file from this device.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'upload'),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload replacement…')),
          ],
        ),
      );
      if (action == 'upload' && mounted) {
        await _uploadReplacement(f);
      }
      return;
    }

    final offloaded =
        widget.store.offloadedFileIds(widget.space.id).contains(f.id);
    if (offloaded) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download from remote?'),
          content: Text('"${f.name}" is not on this device. Fetch it now?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Download')),
          ],
        ),
      );
      if (ok != true) return;
      if (!mounted) return;
      try {
        await widget.store.fetchOffloadedFile(widget.space.id, f.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Download failed: $e')));
        }
        return;
      }
      if (!mounted) return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FileViewerScreen(
          store: widget.store,
          space: widget.space,
          file: f,
          allowDelete: true,
          // Navigate between all files in the space, in creation order
          // (which is the same order the drive grid renders).
          siblings: widget.store.filesForSpace(widget.space.id),
        ),
      ),
    );
  }

  Future<void> _upload(BuildContext context) async {
    try {
      final pickedFiles = await openFiles();
      if (pickedFiles.isEmpty) return;

      var added = 0;
      var failed = 0;
      final failedNames = <String>[];

      for (final picked in pickedFiles) {
        try {
          final bytes = await picked.readAsBytes();
          if (bytes.isEmpty) {
            failed++;
            failedNames.add(picked.name);
            continue;
          }
          await widget.store.addFileFromBytes(
            spaceId: widget.space.id,
            bytes: bytes,
            name: picked.name,
          );
          added++;
        } catch (e) {
          debugPrint('Upload failed for ${picked.name}: $e');
          failed++;
          failedNames.add(picked.name);
        }
      }

      if (!context.mounted) return;

      final parts = <String>[];
      if (added > 0) {
        parts.add('$added ${added == 1 ? "file" : "files"} uploaded');
      }
      if (failed > 0) {
        parts.add('$failed ${failed == 1 ? "file" : "files"} failed');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty ? 'No files uploaded' : parts.join(' · '),
          ),
          action: failed > 0
              ? SnackBarAction(
                  label: 'Details',
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('$failed ${failed == 1 ? "file" : "files"} '
                            'failed to upload'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: failedNames
                                .map((n) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text('· $n'),
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
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(DriveFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${f.name}"?'),
        content: const Text(
            'Posts that reference this file will lose the attachment.'),
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
    if (ok == true) await widget.store.deleteFile(widget.space.id, f.id);
  }

  Future<void> _uploadReplacement(DriveFile f) async {
    try {
      final file = await openFile();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      await widget.store.restoreMissingFile(
        spaceId: widget.space.id,
        fileId: f.id,
        bytes: bytes,
        name: file.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored "${file.name}"')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    List<DriveFile> allFiles,
    Set<String> used,
    int filteredCount,
    String query,
  ) {
    // Selection mode — unchanged behavior, takes priority over search.
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Exit selection',
          onPressed: _exitSelectionMode,
        ),
        title: Text(_selectedFileIds.isEmpty
            ? 'Select files'
            : '${_selectedFileIds.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Select unused',
            onPressed: () {
              final unused = allFiles
                  .where((f) => !used.contains(f.id))
                  .map((f) => f.id)
                  .toSet();
              if (unused.isEmpty) return;
              setState(() {
                _selectedFileIds
                  ..clear()
                  ..addAll(unused);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete selected',
            onPressed: _selectedFileIds.isEmpty ? null : _deleteSelectedFiles,
          ),
        ],
      );
    }

    // Search mode.
    if (_searchActive) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close search',
          onPressed: () => setState(() {
            _searchCtrl.clear();
            _searchActive = false;
          }),
        ),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search files…',
            border: InputBorder.none,
            suffixText:
                query.isEmpty ? null : '$filteredCount / ${allFiles.length}',
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () => setState(_searchCtrl.clear),
            ),
        ],
      );
    }

    // Normal mode.
    return AppBar(
      title: Text('${_space.icon} ${_space.name} · Drive'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: allFiles.isEmpty
              ? null
              : () => setState(() => _searchActive = true),
        ),
        IconButton(
          icon: const Icon(Icons.content_paste),
          tooltip: 'Paste from clipboard',
          onPressed: () => _pasteFromClipboard(),
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: 'Select',
          onPressed: allFiles.isEmpty ? null : () => _enterSelectionMode(),
        ),
        IconButton(
          icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
          tooltip: _grid ? 'List view' : 'Grid view',
          onPressed: () => setState(() => _grid = !_grid),
        ),
      ],
    );
  }

  Future<void> _showFileUsage(DriveFile f) async {
    final posts = widget.store
        .postsForSpace(widget.space.id)
        .where((p) => p.fileIds.contains(f.id))
        .toList();
    await FileUsageSheet.show(
      context,
      file: f,
      posts: posts,
      onViewPostInFeed: widget.onViewPostInFeed,
    );
  }
}

class _GridTile extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final DriveFile file;
  final bool isUsed;
  final bool isOffloaded;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(String action) onMenuAction;

  const _GridTile({
    super.key,
    required this.store,
    required this.space,
    required this.file,
    required this.isUsed,
    required this.isOffloaded,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FileThumbnail(
                    store: store,
                    spaceId: space.id,
                    file: file,
                    iconSize: 40,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Text(
                    file.name,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isUsed ? Colors.black45 : theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isUsed ? Icons.link : Icons.link_off,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            if (isOffloaded)
              Positioned(
                top: 4,
                left: 30,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.cloud, size: 12, color: Colors.white),
                ),
              ),
            Positioned(
              top: 0,
              right: 0,
              child: selectionMode
                  ? Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    )
                  : Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        tooltip: 'More',
                        onSelected: onMenuAction,
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'open', child: Text('Open')),
                          if (isUsed)
                            const PopupMenuItem(
                                value: 'usage',
                                child: Text('Show posts using this file…')),
                          const PopupMenuItem(
                              value: 'share', child: Text('Share / download')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
