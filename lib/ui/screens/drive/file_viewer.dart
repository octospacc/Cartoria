import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../platform/file_save.dart';
import '../../../platform/media.dart';
import '../../../util/file_category.dart';
import '../../widgets/video_aspect.dart';

class FileViewerScreen extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final DriveFile file;

  /// When true (drive screen context), the app bar shows a delete
  /// action. When false (feed inline preview, composer attachment
  /// preview), delete is hidden — the user should remove the file from
  /// the drive screen if they actually want it gone, not from a
  /// read-only preview.
  final bool allowDelete;

  const FileViewerScreen({
    super.key,
    required this.store,
    required this.space,
    required this.file,
    this.allowDelete = true,
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
          if (allowDelete)
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