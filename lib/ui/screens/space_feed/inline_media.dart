import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../platform/media.dart';
import '../../../util/file_category.dart';
import 'media_widgets.dart';

/// Dispatches [file] to the correct inline viewer based on extension.
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
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.readImageBytes(widget.spaceId, widget.file.id);
  }

  @override
  void didUpdateWidget(covariant _InlineImage old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) {
      _future = widget.store.readImageBytes(widget.spaceId, widget.file.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: snap.hasError
                  ? const Icon(Icons.broken_image_outlined)
                  : const CircularProgressIndicator(),
            ),
          );
        }
        final bytes = snap.data!;
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: InteractiveViewer(child: Image.memory(bytes)),
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 320, maxWidth: 600),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
      await player.open(Media(uri), play: false);
      if (!mounted) {
        await player.dispose();
        await releaseMediaUri(uri);
        return;
      }
      _uri = uri;
      _player = player;
      _controller = controller;
      setState(() {});
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
      return MediaErrorCard(
        file: widget.file,
        message: 'Cannot play video',
        onRetry: () {
          setState(() => _error = null);
          _init();
        },
      );
    }
    final controller = _controller;
    final player = _player;
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300,
            maxWidth: 600,
            maxHeight: 320,
          ),
          child: controller == null || player == null
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child:
                        const Center(child: CircularProgressIndicator()),
                  ),
                )
              : StreamBuilder<int?>(
                  stream: player.stream.width,
                  initialData: player.state.width,
                  builder: (context, wSnap) {
                    return StreamBuilder<int?>(
                      stream: player.stream.height,
                      initialData: player.state.height,
                      builder: (context, hSnap) {
                        final w = wSnap.data;
                        final h = hSnap.data;
                        final ratio =
                            (w != null && h != null && w > 0 && h > 0)
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
                            fullscreen:
                                const MaterialVideoControlsThemeData(),
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
        if (text == '\u0000TOO_LARGE') {
          // Fall back to a plain file row so the user can still act on it.
          return FileRow(
            store: widget.store,
            space: Space(
              id: widget.spaceId,
              name: '',
              icon: '',
              createdAt: DateTime.now(),
            ),
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
              SelectableText(
                visibleLines.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
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