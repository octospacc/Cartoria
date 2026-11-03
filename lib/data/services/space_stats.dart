import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;

import '../../util/fs_walk.dart';
import '../models.dart';

class SpaceStats {
  final int totalPosts;
  final int notes; // all notes, including replies
  final int bookmarks; // all bookmarks, including replies
  final int replies; // any post with a parent (regardless of kind)
  final int files;
  final int storageBytes;

  const SpaceStats({
    required this.totalPosts,
    required this.notes,
    required this.bookmarks,
    required this.replies,
    required this.files,
    required this.storageBytes,
  });
}

/// Computes counts + on-disk size for a space.
///
/// Accepts posts/files from the caller (the [VaultStore] facade owns the
/// cache) and only walks the filesystem for the storage figure. Walk the
/// filesystem lazily — call this from a `FutureBuilder`, not on every
/// rebuild.
class SpaceStatsCalculator {
  final FileSystem fs;
  final String vaultPath;

  const SpaceStatsCalculator({required this.fs, required this.vaultPath});

  Future<SpaceStats> compute(
    String spaceId, {
    required List<Post> posts,
    required List<DriveFile> files,
  }) async {
    int notes = 0;
    int bookmarks = 0;
    int replies = 0;
    for (final p in posts) {
      if (p.parentId != null) replies++;
      if (p.kind == PostKind.bookmark) {
        bookmarks++;
      } else {
        notes++;
      }
    }

    int storageBytes = 0;
    try {
      final allFiles =
          await walkFiles(fs.directory(p.join(vaultPath, spaceId)));
      for (final f in allFiles) {
        try {
          storageBytes += (await f.stat()).size;
        } catch (_) {
          // A single unreadable file shouldn't fail the whole stat.
        }
      }
    } catch (_) {
      // A missing space dir also shouldn't fail — the caller may be
      // rendering the dialog just as the space is being deleted.
    }

    return SpaceStats(
      totalPosts: posts.length,
      notes: notes,
      bookmarks: bookmarks,
      replies: replies,
      files: files.length,
      storageBytes: storageBytes,
    );
  }
}