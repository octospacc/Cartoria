import 'dart:typed_data';

import 'models.dart';

/// One drive file extracted from a space zip, in memory.
class ExtractedFile {
  final String name;
  final Uint8List bytes;
  final DateTime createdAt;

  const ExtractedFile({
    required this.name,
    required this.bytes,
    required this.createdAt,
  });
}

/// A space archive decoded in memory: metadata, posts (already parsed via
/// PostRepository.parseContent), and drive files keyed by their id.
///
/// Consumed by VaultStore.importSpaceZipIntoExistingSpace. Not written to
/// disk until the caller decides where to put it.
class ExtractedSpace {
  final String name;
  final String icon;
  final DateTime createdAt;
  final List<Post> posts;
  final Map<String, ExtractedFile> files;

  const ExtractedSpace({
    required this.name,
    required this.icon,
    required this.createdAt,
    required this.posts,
    required this.files,
  });
}