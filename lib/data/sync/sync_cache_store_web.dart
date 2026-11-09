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
/// The local-SHA cache follows the same rule: in-memory per session.
/// The first pull of a session does a full rescan of every post file
/// (569 reads for a modest vault); subsequent pulls reuse the cached
/// SHA and skip the read, which is the difference between a 30–60 s
/// scan and a 1–2 s one on iOS Safari. Page reload resets the cache;
/// that's a deliberate trade against hitting iOS Safari's storage
/// quota.
///
/// The [fs] parameter is accepted for signature compatibility with the
/// IO implementation but is unused.
class SyncCacheStore {
  final FileSystem fs;
  const SyncCacheStore({required this.fs});

  static final Map<String, ({Map<String, String> files, String? commitSha})>
      _cache = {};

  static final Map<
      String,
      Map<String, ({int size, DateTime mtime, String sha})>> _localShas = {};

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
    _localShas.remove(cacheKey);
  }

  /// Loads the cached file-SHA map for [cacheKey]. Empty when no cache
  /// exists yet (first pull of the session).
  Future<Map<String, ({int size, DateTime mtime, String sha})>>
      loadLocalShas(String cacheKey) async {
    return _localShas[cacheKey] ?? {};
  }

  /// Persists the file-SHA map for the next pull in this session.
  /// Called at the end of every `_collectLocalFileShas`.
  Future<void> saveLocalShas(
    String cacheKey,
    Map<String, ({int size, DateTime mtime, String sha})> data,
  ) async {
    _localShas[cacheKey] = data;
  }
}