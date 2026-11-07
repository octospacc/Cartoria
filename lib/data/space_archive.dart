import 'dart:typed_data';

import 'models.dart';

/// Export modes for `VaultStore.exportSpaceZip`.
///
/// Post `fileIds` and `drive_meta.json` are written the same way in all
/// three modes — the difference is only which blobs land in `drive/`.
/// This means an imported incomplete export still knows which files it
/// is missing, so re-importing the full zip (or syncing from the source
/// remote) resolves them.
enum ExportMediaMode {
  /// All file blobs included. Offloaded files are downloaded from the
  /// sync remote before the zip is built.
  full,

  /// Only the file blobs currently on disk. Offloaded files are excluded
  /// (their meta entries remain).
  onDiskOnly,

  /// No drive blobs at all. Only space metadata, entries, and
  /// `drive_meta.json` are written.
  noMedia,
}

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

class ExtractedSpace {
  final String name;
  final String icon;
  final DateTime createdAt;
  final List<Post> posts;
  final Map<String, ExtractedFile> files;

  /// Full `drive_meta.json` from the archive. Superset of `files.keys`:
  /// includes entries whose blobs aren't in the zip (offloaded on the
  /// source, or excluded by `onDiskOnly`/`noMedia` export). Importers
  /// write all of these to preserve references.
  final Map<String, Map<String, dynamic>> driveMeta;

  const ExtractedSpace({
    required this.name,
    required this.icon,
    required this.createdAt,
    required this.posts,
    required this.files,
    this.driveMeta = const {},
  });
}