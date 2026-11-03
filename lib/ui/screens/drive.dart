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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final files = widget.store.filesForSpace(widget.space.id);
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.space.name} · drive'),
            actions: [
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
              : (_grid ? _buildGrid(files) : _buildList(files)),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _upload(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<DriveFile> files) {
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
          onTap: () => _openViewer(f),
          onLongPress: () => _showFileMenu(f),
          onDelete: () => _confirmDelete(f),
        );
      },
    );
  }

  Widget _buildList(List<DriveFile> files) {
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final f = files[i];
        return ListTile(
          leading: Icon(iconForCategory(categoryFor(f.name))),
          title: Text(f.name, overflow: TextOverflow.ellipsis),
          subtitle: Text('${(f.sizeBytes / 1024).toStringAsFixed(1)} KB'),
          onTap: () => _openViewer(f),
          trailing: PopupMenuButton<String>(
            onSelected: (v) => _handleMenu(v, f),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('Open')),
              PopupMenuItem(value: 'share', child: Text('Share / download')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showFileMenu(DriveFile f) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share / download'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action != null) await _handleMenu(action, f);
  }

  Future<void> _handleMenu(String action, DriveFile f) async {
    switch (action) {
      case 'open':
        _openViewer(f);
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

  void _openViewer(DriveFile f) {
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
        spaceId: widget.space.id,
        bytes: bytes,
        name: picked.name,
      );
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
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const _GridTile({
    super.key,
    required this.store,
    required this.space,
    required this.file,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
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
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
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