import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';

/// Recursively lists every regular file under [dir], tolerating errors.
///
/// Symlinks are not followed. Unreadable subdirectories are logged and
/// skipped rather than aborting the whole walk.
///
/// Shared by [ArchiveService.exportSpace] (to zip a space) and
/// [SpaceStatsCalculator.compute] (to total on-disk size), which would
/// otherwise each carry their own copy.
Future<List<File>> walkFiles(Directory dir) async {
  final result = <File>[];
  try {
    if (!await dir.exists()) return result;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File) {
        result.add(e);
      } else if (e is Directory) {
        result.addAll(await walkFiles(e));
      }
    }
  } catch (e) {
    debugPrint('Failed to walk ${dir.path}: $e');
  }
  return result;
}