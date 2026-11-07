import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// SHA-addressed small-image cache. Keyed by the git blob SHA of the
/// source file, so the same content across files/spaces reuses one entry.
/// Bounded to a best-effort recent-1000 by mtime; older entries pruned
/// opportunistically on save.
class ThumbnailCache {
  const ThumbnailCache();

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    // v2: previous cache stored square-distorted thumbnails produced by a
    // buggy `instantiateImageCodec` call. Bumping the directory name
    // orphans those entries without touching them, so a new render
    // regenerates a correct thumbnail on first view.
    final dir = Directory(p.join(support.path, 'cartoria', 'thumbcache-v2'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Uint8List?> get(String sha) async {
    try {
      final dir = await _dir();
      final file = File(p.join(dir.path, '$sha.jpg'));
      if (!await file.exists()) return null;
      // Touch to keep recent entries from being pruned.
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String sha, Uint8List bytes) async {
    try {
      final dir = await _dir();
      await File(p.join(dir.path, '$sha.jpg')).writeAsBytes(bytes);
      await _prune(dir, keep: 1000);
    } catch (_) {}
  }

  Future<void> _prune(Directory dir, {required int keep}) async {
    try {
      final entries = <File>[];
      await for (final e in dir.list(followLinks: false)) {
        if (e is File && e.path.endsWith('.jpg')) entries.add(e);
      }
      if (entries.length <= keep) return;
      // Sort by mtime, oldest first.
      final stats = <({File f, DateTime m})>[];
      for (final f in entries) {
        try {
          stats.add((f: f, m: (await f.stat()).modified));
        } catch (_) {}
      }
      stats.sort((a, b) => a.m.compareTo(b.m));
      for (var i = 0; i < stats.length - keep; i++) {
        try {
          await stats[i].f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
