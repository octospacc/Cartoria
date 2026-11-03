import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../platform/file_save.dart';
import '../../platform/media.dart';
import '../../util/file_category.dart';
import '../widgets/video_aspect.dart';
import '../widgets/file_thumbnail.dart';

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

  IconData _iconFor(String name) {
    switch (categoryFor(name)) {
      case FileCategory.image:
        return Icons.image;
      case FileCategory.video:
        return Icons.videocam;
      case FileCategory.audio:
        return Icons.audio_file;
      case FileCategory.text:
        return Icons.description;
      case FileCategory.pdf:
        return Icons.picture_as_pdf;
      case FileCategory.other:
        return Icons.insert_drive_file;
    }
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

// ---------------------------------------------------------------------------
// Full-screen viewer
// ---------------------------------------------------------------------------

class FileViewerScreen extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final DriveFile file;
  const FileViewerScreen({
    super.key,
    required this.store,
    required this.space,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final category = categoryFor(file.name);
    return Scaffold(
      appBar: AppBar(
        title: Text(file.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share / download',
            onPressed: () async {
              final bytes = await store.readFileBytes(space.id, file.id);
              await saveOrShareFile(bytes, file.name);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: _buildContent(category),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${file.name}"?'),
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
    if (ok == true) {
      await store.deleteFile(space.id, file.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _buildContent(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return _ViewerImage(store: store, spaceId: space.id, file: file);
      case FileCategory.video:
        return _ViewerVideo(store: store, spaceId: space.id, file: file);
      case FileCategory.audio:
        return _ViewerAudio(store: store, spaceId: space.id, file: file);
      case FileCategory.text:
        return _ViewerText(store: store, spaceId: space.id, file: file);
      case FileCategory.pdf:
      case FileCategory.other:
        return _ViewerGeneric(store: store, space: space, file: file);
    }
  }
}

class _ViewerImage extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _ViewerImage({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
  late Future<Uint8List> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.store.readImageBytes(widget.spaceId, widget.file.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return InteractiveViewer(
          child: Center(child: Image.memory(snap.data!)),
        );
      },
    );
  }
}

class _ViewerVideo extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _ViewerVideo({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_ViewerVideo> createState() => _ViewerVideoState();
}

class _ViewerVideoState extends State<_ViewerVideo> {
  Player? _player;
  VideoController? _controller;
  String? _uri;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final bytes =
          await widget.store.readFileBytes(widget.spaceId, widget.file.id);
      final uri = await prepareMediaUri(bytes, widget.file.name);
      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(uri));
      if (!mounted) {
        await player.dispose();
        await releaseMediaUri(uri);
        return;
      }
      _uri = uri;
      _player = player;
      _controller = controller;
      setState(() {});
      await player.play();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    final uri = _uri;
    if (uri != null) releaseMediaUri(uri);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Cannot play video: $_error'));
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: VideoAspect(
        player: _player!,
        child: Video(controller: controller),
      ),
    );
  }
}

class _ViewerAudio extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _ViewerAudio({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_ViewerAudio> createState() => _ViewerAudioState();
}

class _ViewerAudioState extends State<_ViewerAudio> {
  Player? _player;
  String? _uri;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final bytes =
          await widget.store.readFileBytes(widget.spaceId, widget.file.id);
      final uri = await prepareMediaUri(bytes, widget.file.name);
      final player = Player();
      await player.open(Media(uri));
      if (!mounted) {
        await player.dispose();
        await releaseMediaUri(uri);
        return;
      }
      _uri = uri;
      _player = player;
      setState(() {});
      await player.play();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    final uri = _uri;
    if (uri != null) releaseMediaUri(uri);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(child: Text('Cannot play audio: $_error'));
    }
    final player = _player;
    if (player == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audiotrack,
                size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(widget.file.name,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            StreamBuilder<bool>(
              stream: player.stream.playing,
              initialData: player.state.playing,
              builder: (context, snap) {
                final playing = snap.data ?? false;
                return IconButton.filled(
                  iconSize: 48,
                  onPressed: () =>
                      playing ? player.pause() : player.play(),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = player.state.duration;
                final maxMs =
                    dur.inMilliseconds.clamp(1, double.infinity).toDouble();
                final valMs =
                    pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
                return Slider(
                  value: valMs,
                  max: maxMs,
                  onChanged: (v) =>
                      player.seek(Duration(milliseconds: v.toInt())),
                );
              },
            ),
            StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = player.state.duration;
                return Text(
                  '${_fmt(pos)} / ${_fmt(dur)}',
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ViewerText extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _ViewerText({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_ViewerText> createState() => _ViewerTextState();
}

class _ViewerTextState extends State<_ViewerText> {
  late Future<String> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String> _load() async {
    final bytes =
        await widget.store.readFileBytes(widget.spaceId, widget.file.id);
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            snap.data!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.4,
            ),
          ),
        );
      },
    );
  }
}

class _ViewerGeneric extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final DriveFile file;
  const _ViewerGeneric({
    required this.store,
    required this.space,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 96),
            const SizedBox(height: 16),
            Text(file.name,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '${(file.sizeBytes / 1024).toStringAsFixed(1)} KB',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final bytes = await store.readFileBytes(space.id, file.id);
                await saveOrShareFile(bytes, file.name);
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Share / download'),
            ),
          ],
        ),
      ),
    );
  }
}