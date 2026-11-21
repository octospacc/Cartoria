library drive;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../platform/clipboard_files.dart';
import '../../platform/file_save.dart';
import '../../util/file_category.dart';
import '../widgets/escape_back.dart';
import '../widgets/file_thumbnail.dart';
import '../widgets/file_usage_sheet.dart';
import 'drive/file_viewer.dart';

part 'drive/drive_grid_tile.dart';
part 'drive/drive_list_tile.dart';

class DriveScreen extends StatefulWidget {
  final VaultStore store;
  final Space space;
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
    final l = context.l10n;
    final selected = Set<String>.from(_selectedFileIds);
    if (selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.driveDeleteSelectedTitle(selected.length)),
        content: Text(l.driveDeleteSelectedBody),
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
    if (ok != true) return;

    await widget.store.deleteFiles(widget.space.id, selected);
    if (mounted) _exitSelectionMode();
  }

  Future<void> _pasteFromClipboard() async {
    final l = context.l10n;
    try {
      final files = await readClipboardFiles();
      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.drivePasteEmpty)),
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
              SnackBar(content: Text(l.drivePasteFailed(e.toString()))),
            );
          }
        }
      }
      if (mounted && added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.drivePastedFromClipboard(added))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.drivePasteFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l.driveEmptyState,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : files.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l.driveNoMatch(query),
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
                                      _driveSummary(
                                          l, files.length, offloadedCount, unusedCount),
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

  String _driveSummary(
      AppLocalizations l, int total, int offloaded, int unused) {
    final parts = <String>[
      l.driveSummaryTotal(total),
      if (offloaded > 0) l.driveSummaryOffloaded(offloaded),
      if (unused > 0) l.driveSummaryUnused(unused),
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
    return ListView.separated(
      addAutomaticKeepAlives: false,
      itemCount: files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final f = files[i];
        return _DriveListTile(
          key: ValueKey(f.id),
          file: f,
          isUsed: used.contains(f.id),
          isOffloaded: offloadedIds.contains(f.id),
          selectionMode: _selectionMode,
          isSelected: _selectedFileIds.contains(f.id),
          onTap: _selectionMode
              ? () => _toggleSelection(f.id)
              : () => _openViewer(f),
          onLongPress:
              _selectionMode ? null : () => _enterSelectionMode(f.id),
          onMenuAction: (v) => _handleMenu(v, f),
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
    final l = context.l10n;
    if (f.isMissing) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.driveMissingTitle(f.name)),
          content: Text(l.driveMissingBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonCancel)),
            FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'upload'),
                icon: const Icon(Icons.upload_file),
                label: Text(l.driveUploadReplacement)),
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
          title: Text(l.driveDownloadTitle),
          content: Text(l.driveDownloadBody(f.name)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.driveDownloadConfirm)),
          ],
        ),
      );
      if (ok != true) return;
      if (!mounted) return;
      try {
        await widget.store.fetchOffloadedFile(widget.space.id, f.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.driveDownloadFailed(e.toString()))),
          );
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
          siblings: widget.store.filesForSpace(widget.space.id),
        ),
      ),
    );
  }

  Future<void> _upload(BuildContext context) async {
    final l = context.l10n;
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
      if (added > 0) parts.add(l.driveUploadSummaryAdded(added));
      if (failed > 0) parts.add(l.driveUploadSummaryFailed(failed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty ? l.driveUploadNothing : parts.join(' · '),
          ),
          action: failed > 0
              ? SnackBarAction(
                  label: l.spaceImportDetails,
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.driveUploadDialogTitle(failed)),
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
                            child: Text(ctx.l10n.commonClose),
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
          SnackBar(content: Text(l.driveUploadFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _confirmDelete(DriveFile f) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.driveDeleteFileTitle(f.name)),
        content: Text(l.driveDeleteFileBody),
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
    if (ok == true) await widget.store.deleteFile(widget.space.id, f.id);
  }

  Future<void> _uploadReplacement(DriveFile f) async {
    final l = context.l10n;
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
        SnackBar(content: Text(l.driveRestored(file.name))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.driveRestoreFailed(e.toString()))),
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
    final l = context.l10n;
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.driveExitSelection,
          onPressed: _exitSelectionMode,
        ),
        title: Text(_selectedFileIds.isEmpty
            ? l.driveSelectFiles
            : l.driveSelectedCount(_selectedFileIds.length)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: l.driveSelectUnused,
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
            tooltip: l.driveDeleteSelected,
            onPressed: _selectedFileIds.isEmpty ? null : _deleteSelectedFiles,
          ),
        ],
      );
    }

    if (_searchActive) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l.driveSearchClose,
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
            hintText: l.driveSearchHint,
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
              tooltip: l.driveClear,
              onPressed: () => setState(_searchCtrl.clear),
            ),
        ],
      );
    }

    return AppBar(
      title: Text('${_space.icon} ${_space.name} · ${l.driveTitle}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l.driveSearchTooltip,
          onPressed: allFiles.isEmpty
              ? null
              : () => setState(() => _searchActive = true),
        ),
        IconButton(
          icon: const Icon(Icons.content_paste),
          tooltip: l.attachmentPaste,
          onPressed: () => _pasteFromClipboard(),
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: l.feedSelect,
          onPressed: allFiles.isEmpty ? null : () => _enterSelectionMode(),
        ),
        IconButton(
          icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
          tooltip: _grid ? l.driveListTooltip : l.driveGridTooltip,
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
