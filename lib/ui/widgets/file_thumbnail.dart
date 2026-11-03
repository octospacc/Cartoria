import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../util/file_category.dart';

IconData iconForCategory(FileCategory c) {
  switch (c) {
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

/// Renders a file's thumbnail: the image itself if it's an image, otherwise
/// a category icon. Fills the available space.
class FileThumbnail extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cat = categoryFor(file.name);
    if (cat == FileCategory.image) {
      return FutureBuilder<Uint8List>(
        future: store.readImageBytes(spaceId, file.id),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.memory(
            snap.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    }
    return Center(child: Icon(iconForCategory(cat), size: iconSize));
  }
}