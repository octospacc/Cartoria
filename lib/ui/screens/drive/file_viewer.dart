import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/file_save.dart';
import '../../../platform/media.dart';
import '../../../platform/clipboard_write.dart';
import '../../../util/file_category.dart';
import '../../widgets/video_aspect.dart';

class FileViewerScreen extends StatefulWidget {
  final VaultStore store;
  final Space space;
  final DriveFile file;
  final bool allowDelete;
  final List<DriveFile>? siblings;

  const FileViewerScreen({
    super.key,
    required this.store,
    required this.space,
    required this.file,
    this.allowDelete = true,
    this.siblings,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late final List<DriveFile> _files;
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final sib = widget.siblings;
    if (sib != null && sib.isNotEmpty) {
      final idx = sib.indexWhere((f) => f.id == widget.file.id);
      if (idx >= 0) {
        _files = List.unmodifiable(sib);
        _currentIndex = idx;
      } else {
        _files = List.unmodifiable([widget.file]);
        _currentIndex = 0;
      }
    } else {
      _files = List.unmodifiable([widget.file]);
      _currentIndex = 0;
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DriveFile get _currentFile => _files[_currentIndex];
  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext => _currentIndex < _files.length - 1;
  bool get _isMulti => _files.length > 1;

  void _goPrev() {
    if (!_hasPrev || !_pageController.hasClients) return;
    _pageController.animateToPage(
      _currentIndex - 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _goNext() {
    if (!_hasNext || !_pageController.hasClients) return;
    _pageController.animateToPage(
      _currentIndex + 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _close() {
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) Navigator.of(context).maybePop();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft && _hasPrev) {
      _goPrev();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight && _hasNext) {
      _goNext();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final file = _currentFile;
    final theme = Theme.of(context);
    final l = context.l10n;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(
                child: Text(file.name, overflow: TextOverflow.ellipsis),
              ),
              if (_isMulti) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_files.length}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (categoryFor(file.name) == FileCategory.image)
              IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                tooltip: l.fileViewerCopyImage,
                onPressed: () => _copyImageToClipboard(context, file),
              ),
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: l.driveShareAction,
              onPressed: () async {
                final bytes =
                    await widget.store.readFileBytes(widget.space.id, file.id);
                await saveOrShareFile(bytes, file.name);
              },
            ),
            if (widget.allowDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l.driveDeleteAction,
                onPressed: () => _delete(context),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (_isMulti)
              PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final f = _files[index];
                  return KeyedSubtree(
                    key: ValueKey(f.id),
                    child: _buildPage(f),
                  );
                },
              )
            else
              _buildPage(file),
            if (_hasPrev)
              _NavArrow(
                alignment: Alignment.centerLeft,
                icon: Icons.chevron_left,
                onTap: _goPrev,
              ),
            if (_hasNext)
              _NavArrow(
                alignment: Alignment.centerRight,
                icon: Icons.chevron_right,
                onTap: _goNext,
              ),
            if (_isMulti)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(child: _buildIndicator(theme)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(DriveFile file) {
    switch (categoryFor(file.name)) {
      case FileCategory.image:
        return _ViewerImage(
          store: widget.store,
          spaceId: widget.space.id,
          file: file,
        );
      case FileCategory.video:
        return _ViewerVideo(
          store: widget.store,
          spaceId: widget.space.id,
          file: file,
        );
      case FileCategory.audio:
        return _ViewerAudio(
          store: widget.store,
          spaceId: widget.space.id,
          file: file,
        );
      case FileCategory.text:
        return _ViewerText(
          store: widget.store,
          spaceId: widget.space.id,
          file: file,
        );
      case FileCategory.pdf:
      case FileCategory.other:
        return _ViewerGeneric(
          store: widget.store,
          space: widget.space,
          file: file,
        );
    }
  }

  Widget _buildIndicator(ThemeData theme) {
    if (_files.length <= 1 || _files.length > 10) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_files.length, (i) {
          final active = i == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: active ? 8 : 6,
            height: active ? 8 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white54,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final l = context.l10n;
    final file = _currentFile;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.driveDeleteFileTitle(file.name)),
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
    if (ok == true) {
      await widget.store.deleteFile(widget.space.id, file.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _copyImageToClipboard(
    BuildContext context,
    DriveFile file,
  ) async {
    final l = context.l10n;
    try {
      final bytes = await widget.store.readFileBytes(widget.space.id, file.id);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final pngData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (pngData == null) throw StateError('encode failed');
      await copyImageToClipboard(pngData.buffer.asUint8List());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.fileViewerCopiedToClipboard)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.fileViewerCopyFailed(e.toString()))),
        );
      }
    }
  }
}

class _NavArrow extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrow({
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
          ),
        ),
      ),
    );
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
    _future = _load();
  }

  Future<Uint8List> _load() async {
    await widget.store.ensureFileLocal(widget.spaceId, widget.file.id);
    return widget.store.readImageBytes(widget.spaceId, widget.file.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ViewerError(
            message: l.fileViewerImageLoadFailed,
            error: snap.error,
            onRetry: () => setState(() => _future = _load()),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(
            child: Image.memory(snap.data!, fit: BoxFit.contain),
          ),
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
      await widget.store.ensureFileLocal(widget.spaceId, widget.file.id);
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
      return Center(
          child: Text(context.l10n.fileViewerCannotPlayVideo(_error!)));
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
      await widget.store.ensureFileLocal(widget.spaceId, widget.file.id);
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
      return Center(
          child: Text(context.l10n.fileViewerCannotPlayAudio(_error!)));
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
            Icon(Icons.audiotrack, size: 96, color: theme.colorScheme.primary),
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
                  onPressed: () => playing ? player.pause() : player.play(),
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
    await widget.store.ensureFileLocal(widget.spaceId, widget.file.id);
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
    final l = context.l10n;
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
                await store.ensureFileLocal(space.id, file.id);
                final bytes = await store.readFileBytes(space.id, file.id);
                await saveOrShareFile(bytes, file.name);
              },
              icon: const Icon(Icons.ios_share),
              label: Text(l.driveShareAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerError extends StatelessWidget {
  final String message;
  final Object? error;
  final VoidCallback onRetry;

  const _ViewerError({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.titleMedium),
            if (error != null) ...[
              const SizedBox(height: 6),
              SelectableText(
                error.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l.fileViewerRetry),
            ),
          ],
        ),
      ),
    );
  }
}