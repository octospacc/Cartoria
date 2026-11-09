import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../platform/media.dart';
import '../../../util/file_category.dart';
import 'media_widgets.dart';

class InlineMedia extends StatelessWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;

  const InlineMedia({
    super.key,
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    switch (categoryFor(file.name)) {
      case FileCategory.image:
        return _InlineImage(store: store, spaceId: spaceId, file: file);
      case FileCategory.video:
        return _InlineVideo(store: store, spaceId: spaceId, file: file);
      case FileCategory.audio:
        return _InlineAudio(store: store, spaceId: spaceId, file: file);
      case FileCategory.text:
        return _InlineText(store: store, spaceId: spaceId, file: file);
      case FileCategory.pdf:
      case FileCategory.other:
        return const SizedBox.shrink();
    }
  }
}

// ── Image ─────────────────────────────────────────────────────────────────

class _InlineImageData {
  final Uint8List bytes;
  final double aspectRatio;
  const _InlineImageData(this.bytes, this.aspectRatio);
}

class _InlineImage extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineImage({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineImage> createState() => _InlineImageState();
}

class _InlineImageState extends State<_InlineImage> {
  late Future<_InlineImageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _InlineImage old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) {
      _future = _load();
    }
  }

  Future<_InlineImageData> _load() async {
    final offloaded =
        widget.store.offloadedFileIds(widget.spaceId).contains(widget.file.id);

    final bytes = offloaded
        ? await widget.store
            .fetchThumbnailForOffloaded(widget.spaceId, widget.file.id)
        : await widget.store.readImageBytes(widget.spaceId, widget.file.id);

    final ratio = await _aspectOf(bytes);
    return _InlineImageData(bytes, ratio);
  }

  /// Actual aspect ratio of [bytes]. Falls back to the cached value for
  /// this file (set on a previous render), then to decoding the image.
  Future<double> _aspectOf(Uint8List bytes) async {
    final cached =
        widget.store.imageAspectRatio(widget.spaceId, widget.file.id);
    if (cached != null) return cached;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      final ratio = (w > 0 && h > 0) ? w / h : 16.0 / 9.0;
      frame.image.dispose();
      codec.dispose();
      widget.store.cacheImageAspect(widget.spaceId, widget.file.id, ratio);
      return ratio;
    } catch (_) {
      return 16.0 / 9.0;
    }
  }

  Future<void> _onTap() async {
    final offloaded =
        widget.store.offloadedFileIds(widget.spaceId).contains(widget.file.id);

    if (offloaded) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download from remote?'),
          content: Text('"${widget.file.name}" is not on this device. '
              'Fetch it now?'),
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
      if (ok != true || !mounted) return;
      try {
        await widget.store.fetchOffloadedFile(widget.spaceId, widget.file.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Download failed: $e')));
        }
        return;
      }
      if (!mounted) return;
      setState(() => _future = _load());
    }

    if (!mounted) return;
    _InlineImageData data;
    try {
      data = await _future;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load image: $e')));
      }
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.memory(data.bytes)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_InlineImageData>(
      future: _future,
      builder: (context, snap) {
        final ratio = snap.data?.aspectRatio ??
            widget.store.imageAspectRatio(widget.spaceId, widget.file.id) ??
            16.0 / 9.0;

        final box = ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320, maxWidth: 600),
          child: AspectRatio(
            aspectRatio: ratio,
            child: snap.hasError || !snap.hasData
                ? Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: snap.hasError
                          ? const Icon(Icons.broken_image_outlined)
                          : const CircularProgressIndicator(),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      snap.data!.bytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
          ),
        );

        if (snap.hasError || !snap.hasData) {
          return Align(alignment: Alignment.centerLeft, child: box);
        }
        return GestureDetector(
          onTap: _onTap,
          child: Align(alignment: Alignment.centerLeft, child: box),
        );
      },
    );
  }
}

// ── Video ─────────────────────────────────────────────────────────────────

class _InlineVideo extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineVideo({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<_InlineVideo> {
  Player? _player;
  VideoController? _controller;
  String? _uri;
  String? _error;
  bool _loading = false;

  Future<void> _start() async {
    if (_loading || _player != null) return;

    final offloaded =
        widget.store.offloadedFileIds(widget.spaceId).contains(widget.file.id);

    if (offloaded) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download from remote?'),
          content: Text('"${widget.file.name}" is not on this device. '
              'Fetch it now?'),
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
        await widget.store.fetchOffloadedFile(widget.spaceId, widget.file.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Download failed: $e')));
        }
        return;
      }
      if (!mounted) return;
    }

    setState(() => _loading = true);
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
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
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
      return MediaErrorCard(
        file: widget.file,
        message: 'Cannot play video',
        onRetry: () => setState(() => _error = null),
      );
    }
    final controller = _controller;
    final player = _player;
    if (controller == null || player == null) {
      final offloaded = widget.store
          .offloadedFileIds(widget.spaceId)
          .contains(widget.file.id);
      return _VideoPreviewCard(
        file: widget.file,
        isOffloaded: offloaded,
        loading: _loading,
        onTap: _start,
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minWidth: 300, maxWidth: 600, maxHeight: 320),
          child: StreamBuilder<int?>(
            stream: player.stream.width,
            initialData: player.state.width,
            builder: (context, wSnap) {
              return StreamBuilder<int?>(
                stream: player.stream.height,
                initialData: player.state.height,
                builder: (context, hSnap) {
                  final w = wSnap.data;
                  final h = hSnap.data;
                  final ratio = (w != null && h != null && w > 0 && h > 0)
                      ? w / h
                      : 16.0 / 9.0;
                  return AspectRatio(
                    aspectRatio: ratio,
                    child: MaterialVideoControlsTheme(
                      normal: MaterialVideoControlsThemeData(
                        displaySeekBar: true,
                        buttonBarButtonSize: 18.0,
                        buttonBarHeight: 32.0,
                        seekBarHeight: 2.0,
                        padding: EdgeInsets.zero,
                        bottomButtonBarMargin: EdgeInsets.zero,
                        topButtonBar: const [],
                        primaryButtonBar: const [],
                        bottomButtonBar: const [
                          MaterialPlayOrPauseButton(),
                          MaterialPositionIndicator(),
                        ],
                      ),
                      fullscreen: const MaterialVideoControlsThemeData(),
                      child: Video(controller: controller),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Audio ─────────────────────────────────────────────────────────────────

class _InlineAudio extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineAudio({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineAudio> createState() => _InlineAudioState();
}

class _InlineAudioState extends State<_InlineAudio> {
  Player? _player;
  String? _uri;
  bool _loading = false;
  String? _error;

  Future<void> _start() async {
    if (_loading || _player != null) return;

    final offloaded =
        widget.store.offloadedFileIds(widget.spaceId).contains(widget.file.id);

    if (offloaded) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download from remote?'),
          content: Text('"${widget.file.name}" is not on this device. '
              'Fetch it now?'),
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
        await widget.store.fetchOffloadedFile(widget.spaceId, widget.file.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Download failed: $e')));
        }
        return;
      }
      if (!mounted) return;
    }

    setState(() => _loading = true);
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
      setState(() => _loading = false);
      await player.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
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
      return MediaErrorCard(
        file: widget.file,
        message: 'Cannot play audio',
        onRetry: () => setState(() => _error = null),
      );
    }
    final player = _player;
    if (player != null) {
      return AudioControls(player: player, file: widget.file);
    }
    return PlayCard(
      file: widget.file,
      icon: Icons.audiotrack,
      label: 'Tap to play audio',
      loading: _loading,
      onTap: _start,
    );
  }
}

// ── Text ──────────────────────────────────────────────────────────────────

class _InlineText extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineText({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  late Future<String> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _InlineText old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) {
      _future = _load();
      _expanded = false;
    }
  }

  Future<String> _load() async {
    final offloaded =
        widget.store.offloadedFileIds(widget.spaceId).contains(widget.file.id);

    if (offloaded) {
      // Text attachments can be large; fetching the whole file to preview
      // defeats the point of offloading. Require an explicit download.
      return '\u0000OFFLOADED';
    }

    final bytes =
        await widget.store.readFileBytes(widget.spaceId, widget.file.id);
    if (bytes.length > kMaxTextPreviewBytes) {
      return '\u0000TOO_LARGE';
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final text = snap.data!;

        if (text == '\u0000OFFLOADED') {
          return PlayCard(
            file: widget.file,
            icon: Icons.cloud_download_outlined,
            label: 'Offloaded — tap to download',
            loading: false,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Download from remote?'),
                  content: Text('"${widget.file.name}" is not on this '
                      'device. Fetch it now?'),
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
                await widget.store
                    .fetchOffloadedFile(widget.spaceId, widget.file.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')));
                }
                return;
              }
              if (!mounted) return;
              setState(() => _future = _load());
            },
          );
        }

        if (text == '\u0000TOO_LARGE') {
          return FileRow(
            store: widget.store,
            spaceId: widget.spaceId,
            file: widget.file,
          );
        }

        final lines = text.split('\n');
        final visibleLines =
            _expanded ? lines : lines.take(8).toList(growable: false);
        final truncated = !_expanded && lines.length > 8;
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.file.name,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_expanded ? 'Collapse' : 'Expand'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                visibleLines.join('\n'),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, height: 1.35),
              ),
              if (truncated)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('…', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Video preview card ───────────────────────────────────────────────────

/// Poster-style card shown in place of a video before the player loads.
///
/// 16:9 dark surface, centered play button, filename + size at bottom.
/// If [thumbnail] is provided (extracted frame, cached from a previous
/// play) it's shown as the background; otherwise a themed gradient
/// stands in. If [isOffloaded], the button uses a cloud icon so the
/// user knows a download is required.
class _VideoPreviewCard extends StatelessWidget {
  final DriveFile file;
  final bool isOffloaded;
  final bool loading;
  final VoidCallback onTap;
  final Uint8List? thumbnail;

  const _VideoPreviewCard({
    required this.file,
    required this.isOffloaded,
    required this.loading,
    required this.onTap,
    this.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 320),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Material(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: loading ? null : onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background: real frame if available, else gradient.
                  if (thumbnail != null)
                    Image.memory(
                      thumbnail!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                  // Scrim over the lower half so the info bar is legible
                  // on any background (gradient or a bright frame).
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Play button
                  Center(
                    child: loading
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              isOffloaded
                                  ? Icons.cloud_download_outlined
                                  : Icons.play_arrow,
                              size: 36,
                              color: Colors.black87,
                            ),
                          ),
                  ),
                  // Info bar: icon, filename, size
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        Icon(
                          isOffloaded ? Icons.cloud : Icons.videocam,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            file.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatSize(file.sizeBytes),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
