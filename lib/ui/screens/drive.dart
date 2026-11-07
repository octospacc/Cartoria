import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../platform/file_save.dart';
import '../../util/file_category.dart';
import '../widgets/file_thumbnail.dart';
import 'drive/file_viewer.dart';

class DriveScreen extends StatefulWidget {
  final VaultStore store;
  final Space space;
  const DriveScreen({super.key, required this.store, required this.space});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  bool _grid = true;
  bool _selectionMode = false;
  final Set<String> _selectedFileIds = {};

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final files = widget.store.filesForSpace(widget.space.id);
        final offloadedIds = widget.store.offloadedFileIds(widget.space.id);
        final used = widget.store.usedFileIds(widget.space.id);
        final offloadedCount =
            files.where((f) => offloadedIds.contains(f.id)).length;
        final localCount = files.length - offloadedCount;

        return Scaffold(
          appBar: _selectionMode
              ? AppBar(
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
                        final unused = files
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
                      onPressed: _selectedFileIds.isEmpty
                          ? null
                          : _deleteSelectedFiles,
                    ),
                  ],
                )
              : AppBar(
                  title: Text('${widget.space.name} · Drive'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.checklist),
                      tooltip: 'Select',
                      onPressed:
                          files.isEmpty ? null : () => _enterSelectionMode(),
                    ),
                    IconButton(
                      icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                      tooltip: _grid ? 'List view' : 'Grid view',
                      onPressed: () => setState(() => _grid = !_grid),
                    ),
                  ],
                ),
          body: files.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No files yet.\nUpload one here, or attach from a post.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (offloadedCount > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Row(
                          children: [
                            Icon(Icons.cloud,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              '$localCount local · $offloadedCount offloaded',
                              style: theme.textTheme.bodySmall,
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
    );
  }

  Widget _buildGrid(
    List<DriveFile> files,
    Set<String> offloadedIds,
    Set<String> used,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
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
          onDelete: () => _confirmDelete(f),
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
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Open')),
                    PopupMenuItem(
                        value: 'share', child: Text('Share / download')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
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
      case 'share':
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
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('"${f.name}" is missing'),
          content: const Text(
            'This file is referenced by one or more posts, but its content '
            'isn\'t stored anywhere on this device or the sync remote.\n\n'
            'To restore it, re-import the full export of the space it came '
            'from, or pull from the sync remote if it still has the file.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        ),
      );
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

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FileViewerScreen(
          store: widget.store,
          space: widget.space,
          file: f,
        ),
      ),
    );
  }

  Future<void> _upload(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final picked = result?.files.single;
      final bytes = picked?.bytes;
      if (bytes == null || picked == null) return;
      await widget.store.addFileFromBytes(
          spaceId: widget.space.id, bytes: bytes, name: picked.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
  final VoidCallback onDelete;

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
    required this.onDelete,
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
              top: 4,
              right: 4,
              child: selectionMode
                  ? Container(
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
                    )
                  : Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onDelete,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child:
                              Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
