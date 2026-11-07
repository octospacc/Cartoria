import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../util/file_category.dart';

IconData iconForCategory(FileCategory c) {
  switch (c) {
    case FileCategory.image: return Icons.image;
    case FileCategory.video: return Icons.videocam;
    case FileCategory.audio: return Icons.audio_file;
    case FileCategory.text: return Icons.description;
    case FileCategory.pdf: return Icons.picture_as_pdf;
    case FileCategory.other: return Icons.insert_drive_file;
  }
}

class FileThumbnail extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  final double iconSize;
  const FileThumbnail({
    super.key,
    required this.store,
    required this.spaceId,
    required this.file,
    this.iconSize = 40,
  });

  @override
  State<FileThumbnail> createState() => _FileThumbnailState();
}

class _FileThumbnailState extends State<FileThumbnail> {
  Uint8List? _bytes;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FileThumbnail old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) {
      _bytes = null;
      _error = false;
      _load();
    }
  }

  Future<void> _load() async {
    final cat = categoryFor(widget.file.name);
    if (cat != FileCategory.image) return;
    final offloaded =
        widget.store.offloadedFileIds(widget.spaceId).contains(widget.file.id);

    if (offloaded) {
      // Try the thumbnail cache first — if hit, no network fetch.
      final info = await widget.store.offloadedInfoFor(
          widget.spaceId, widget.file.id);
      if (info != null) {
        final cached = await widget.store.thumbnailCache.get(info.remoteSha);
        if (cached != null && mounted) {
          setState(() => _bytes = cached);
          return;
        }
      }
    }

    setState(() => _loading = true);
    try {
      final bytes = offloaded
          ? await widget.store.fetchThumbnailForOffloaded(
              widget.spaceId, widget.file.id)
          : await widget.store.readImageBytes(
              widget.spaceId, widget.file.id);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = categoryFor(widget.file.name);
    final offloaded =
        widget.store.offloadedFileIds(widget.spaceId).contains(widget.file.id);

    Widget content;
    if (cat == FileCategory.image) {
      if (_bytes != null) {
        content = Image.memory(_bytes!, fit: BoxFit.cover,
            width: double.infinity, height: double.infinity);
      } else if (_error) {
        content = Center(
          child: Icon(Icons.cloud_off, size: widget.iconSize,
              color: theme.colorScheme.error),
        );
      } else if (_loading) {
        content = const Center(child: CircularProgressIndicator());
      } else {
        content = const SizedBox.shrink();
      }
    } else {
      content = Center(
          child: Icon(iconForCategory(cat), size: widget.iconSize));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (offloaded)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.cloud,
                  size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}