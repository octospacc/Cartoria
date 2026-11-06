import 'package:fs_shim/fs_shim.dart';

/// In-memory, per-session cache.
///
/// A remote-listing cache for 26K files is ~2 MB. `localStorage` caps
/// at 5–10 MB per origin, shared with the token store and any other
/// app data — close enough that it isn't safe to consume it for a
/// cache. `IndexedDB` would work but requires a pubspec dependency
/// (`idb_shim`) and is overkill for data that's already regenerable in
/// one `GET /git/trees?recursive=1` call.
///
/// Losing the cache on reload means the next push re-lists the remote
/// once; after that, the HEAD-SHA check keeps it warm until the page
/// unloads. Same behaviour as if there were no cache at all.
///
/// The [fs] parameter is accepted for signature compatibility with the
/// IO implementation but is unused.
class SyncCacheStore {
  final FileSystem fs;
  const SyncCacheStore({required this.fs});

  static final Map<String, ({Map<String, String> files, String? commitSha})>
      _cache = {};

  Future<({Map<String, String> files, String? commitSha})?> load(
    String cacheKey,
  ) async =>
      _cache[cacheKey];

  Future<void> save(
    String cacheKey,
    Map<String, String> files,
    String? commitSha,
  ) async {
    _cache[cacheKey] = (files: files, commitSha: commitSha);
  }

  Future<void> clear(String cacheKey) async {
    _cache.remove(cacheKey);
  }
}