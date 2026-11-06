import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/fs.dart';
import '../util/fs_walk.dart';
import '../util/mime.dart';
import '../util/hook_outcome.dart';
import 'bookmarks.dart';
import 'hooks.dart';
import 'models.dart';
import 'repos/archive_service.dart';
import 'repos/bookmarks_importer.dart';
import 'repos/drive_repo.dart';
import 'repos/hooks_repo.dart';
import 'repos/post_repo.dart';
import 'repos/space_repo.dart';
import 'services/hook_executor.dart';
import 'services/link_metadata.dart';
import 'services/space_stats.dart';
import 'sync/sync_config.dart';
import 'sync/github_provider.dart';
import 'sync/gitlab_provider.dart';
import 'sync/sync_provider.dart';
import 'sync/sync_service.dart';
import 'space_archive.dart';

export 'repos/bookmarks_importer.dart' show BookmarkImportResult;
export 'services/link_metadata.dart' show LinkMetadata;
export 'services/space_stats.dart' show SpaceStats;
export 'space_archive.dart' show ExtractedFile, ExtractedSpace;

class SpaceImportResult {
  final int total;
  final int imported;
  final int skippedDuplicates;
  final int filesImported;
  final int filesSkipped;

  const SpaceImportResult({
    required this.total,
    required this.imported,
    required this.skippedDuplicates,
    required this.filesImported,
    required this.filesSkipped,
  });
}

class VaultStore extends ChangeNotifier {
  late final FileSystem fs;
  late final String vaultPath;

  late final SpaceRepository _spaces;
  late final PostRepository _posts;
  late final DriveRepository _drive;
  late final ArchiveService _archive;
  late final LinkMetadataService _link;
  late final SpaceStatsCalculator _stats;
  late final HooksRepository _hooks;
  late final HookExecutor _executor;
  late final BookmarksImporter _bookmarksImporter;
  late final SyncConfigStore _syncConfigStore;
  late final SyncTokenStore _syncTokenStore;
  late final SyncCacheStore _syncCacheStore;

  final http.Client _httpClient = http.Client();

  final List<Space> _spaceCache = [];
  final Map<String, List<Post>> _postCache = {};
  final Map<String, List<DriveFile>> _fileCache = {};
  final Map<String, Map<String, DriveFile>> _fileIndex = {};
  final Map<String, Uint8List> _imageCache = {};

  final Map<String, Future<void>> _postLocks = {};
  final Map<String, Future<void>> _hookChains = {};
  final Set<String> _activeHookRuns = {};

  SyncConfig? _cachedSyncConfig;
  SyncConfig? get syncConfig => _cachedSyncConfig;

  // ── Read accessors ─────────────────────────────────────────────────────

  List<Space> get spaces => List.unmodifiable(_spaceCache);

  List<Post> postsForSpace(String spaceId) =>
      List.unmodifiable(_postCache[spaceId] ?? const <Post>[]);

  List<DriveFile> filesForSpace(String spaceId) =>
      List.unmodifiable(_fileCache[spaceId] ?? const <DriveFile>[]);

  List<Hook> get hooks => _hooks.all;

  Space? spaceById(String id) {
    for (final s in _spaceCache) {
      if (s.id == id) return s;
    }
    return null;
  }

  DriveFile? fileById(String spaceId, String fileId) =>
      _fileIndex[spaceId]?[fileId];

  void _rebuildFileIndex(String spaceId) {
    _fileIndex[spaceId] = {
      for (final f in _fileCache[spaceId] ?? const <DriveFile>[]) f.id: f,
    };
  }

  final Map<String, double> _imageAspectCache = {};

  /// Aspect ratio (width / height) for a drive image, cached after first
  /// decode. Used by inline media rendering to reserve the correct space
  /// before the image loads, eliminating layout jumps during scroll.
  double? imageAspectRatio(String spaceId, String fileId) =>
      _imageAspectCache['$spaceId:$fileId'];

  void cacheImageAspect(String spaceId, String fileId, double ratio) {
    if (ratio <= 0 || !ratio.isFinite) return;
    _imageAspectCache['$spaceId:$fileId'] = ratio;
  }

  // ── Usage ordering ─────────────────────────────────────────────────────

  /// Reorders [_spaceCache] so the most recently used spaces come first.
  ///
  /// "Last used" for a space is
  /// `max(space.createdAt, max post.createdAt)`. Posts include replies
  /// (they're stored in the same `_postCache[spaceId]`). Using the
  /// space's own creation time as a floor keeps freshly created or
  /// freshly imported spaces near the top even when every imported post
  /// carries a backdated `ADD_DATE`.
  ///
  /// Called on load and after any mutation that changes a space's newest
  /// post. Edits do **not** trigger a re-sort: they don't change
  /// `createdAt`, so they don't count as "posting".
  void _resortSpacesByUsage() {
    _spaceCache.sort((a, b) {
      final aKey = _lastUsedAt(a);
      final bKey = _lastUsedAt(b);
      return bKey.compareTo(aKey);
    });
  }

  DateTime _lastUsedAt(Space space) {
    var max = space.createdAt;
    final posts = _postCache[space.id] ?? const <Post>[];
    for (final p in posts) {
      if (p.createdAt.isAfter(max)) max = p.createdAt;
    }
    return max;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  Future<void> init() async {
    fs = createFs();
    if (kIsWeb) {
      vaultPath = '/vault';
    } else {
      final docs = await getApplicationDocumentsDirectory();
      vaultPath = p.join(docs.path, 'vault');
    }
    await fs.directory(vaultPath).create(recursive: true);

    _spaces = SpaceRepository(fs: fs, vaultPath: vaultPath);
    _posts = PostRepository(fs: fs, vaultPath: vaultPath);
    _drive = DriveRepository(fs: fs, vaultPath: vaultPath);
    _archive = ArchiveService(fs: fs, vaultPath: vaultPath);
    _stats = SpaceStatsCalculator(fs: fs, vaultPath: vaultPath);
    _hooks = HooksRepository(fs: fs, vaultPath: vaultPath);
    _executor = HookExecutor(client: _httpClient);
    _bookmarksImporter = BookmarksImporter(posts: _posts);
    _syncConfigStore = SyncConfigStore(fs: fs, vaultPath: vaultPath);
    _syncTokenStore = SyncTokenStore(fs: fs);
    _syncCacheStore = SyncCacheStore(fs: fs);
    _link = LinkMetadataService(
      proxyUrl: kIsWeb ? 'https://corsproxy.io/?url={url}' : null,
    );

    await _hooks.load();
    _cachedSyncConfig = await _syncConfigStore.load();
    await reload();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Future<void> reload() async {
    await _migratePostFolders();
    await _spaces.migrateHtmlToJson();
    await _hooks.migrateSingleFileToFolder();

    _drive.clearCache();
    _spaceCache.clear();
    _postCache.clear();
    _fileCache.clear();
    _fileIndex.clear();
    _imageAspectCache.clear();

    final spaces = await _spaces.list();
    for (final space in spaces) {
      _spaceCache.add(space);
      try {
        _postCache[space.id] = await _posts.list(space.id);
        _fileCache[space.id] = await _drive.list(space.id);
        _rebuildFileIndex(space.id);
      } catch (e) {
        debugPrint('Failed to load space ${space.id}: $e');
        _postCache[space.id] = [];
        _fileCache[space.id] = [];
        _fileIndex[space.id] = {};
      }
    }
    _resortSpacesByUsage();
    notifyListeners();
  }

  /// One-shot migration of legacy `posts/` directories into `entries/`.
  ///
  /// Runs at every reload, but is a no-op after the first successful pass
  /// per space. Failures are logged and *do not* block the reload — the
  /// [PostRepository] falls back to `posts/` at read time, so a space whose
  /// migration failed still functions; it just stays on the old folder
  /// name until the underlying issue is resolved.
  Future<void> _migratePostFolders() async {
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return;

    final pending = <Directory>[];
    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      final oldDir = fs.directory(p.join(e.path, 'posts'));
      if (!await oldDir.exists()) continue;

      final newDir = fs.directory(p.join(e.path, 'entries'));
      if (await newDir.exists()) {
        // Both exist — likely a partial migration or manual copy. Leave it:
        // entries/ wins at read time, posts/ is dead weight the user can
        // clean up. Warn so it shows up in logs if it ever happens.
        debugPrint('Both posts/ and entries/ exist in ${e.path}; '
            'leaving both, entries/ takes precedence');
        continue;
      }
      pending.add(oldDir);
    }

    for (final oldDir in pending) {
      try {
        await oldDir.rename(p.join(p.dirname(oldDir.path), 'entries'));
      } catch (err) {
        debugPrint('Migration posts/→entries/ failed for ${oldDir.path}: $err. '
            'PostRepository will fall back to reading from posts/.');
      }
    }
  }

  // ── Spaces ─────────────────────────────────────────────────────────────

  Future<Space> createSpace({required String name, String icon = '📓'}) async {
    final space = await _spaces.create(name: name, icon: icon);
    _spaceCache.insert(0, space);
    _postCache[space.id] = [];
    _fileCache[space.id] = [];
    _fileIndex[space.id] = {};
    _resortSpacesByUsage();
    notifyListeners();
    return space;
  }

  Future<void> updateSpace(
    String spaceId, {
    required String name,
    required String icon,
  }) async {
    final updated = await _spaces.update(
      spaceId: spaceId,
      name: name,
      icon: icon,
    );
    final idx = _spaceCache.indexWhere((s) => s.id == spaceId);
    if (idx >= 0) _spaceCache[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteSpace(String spaceId) async {
    await _spaces.delete(spaceId);
    _spaceCache.removeWhere((s) => s.id == spaceId);
    _postCache.remove(spaceId);
    _fileCache.remove(spaceId);
    _fileIndex.remove(spaceId);
    _imageCache.removeWhere((k, _) => k.startsWith('$spaceId:'));
    notifyListeners();
  }

  // ── Posts ──────────────────────────────────────────────────────────────

  Future<Post> createPost({
    required String spaceId,
    required PostKind kind,
    required String plaintextBody,
    String? url,
    String? title,
    String? description,
    String? thumbnail,
    String? parentId,
    List<String> tags = const [],
    List<String> fileIds = const [],
  }) async {
    final post = await _posts.create(
      spaceId: spaceId,
      kind: kind,
      plaintextBody: plaintextBody,
      url: url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      parentId: parentId,
      tags: tags,
      fileIds: fileIds,
    );
    _postCache.putIfAbsent(spaceId, () => []).add(post);
    _resortSpacesByUsage();
    notifyListeners();

    final space = spaceById(spaceId);
    if (space != null) {
      _scheduleHooks(
        post: post,
        original: null,
        space: space,
        trigger: HookTrigger.create,
      );
    }
    return post;
  }

  Future<void> updatePost({
    required String spaceId,
    required String postId,
    required PostKind kind,
    required String plaintextBody,
    String? url,
    String? title,
    String? description,
    String? thumbnail,
    List<String> tags = const [],
    List<String> fileIds = const [],
  }) async {
    final list = _postCache[spaceId];
    if (list == null) return;
    final idx = list.indexWhere((x) => x.id == postId);
    if (idx < 0) return;
    final previous = list[idx];

    final updated = await _withPostLock(postId, () async {
      final p = await _posts.update(
        spaceId: spaceId,
        existing: previous,
        kind: kind,
        plaintextBody: plaintextBody,
        url: url,
        title: title,
        description: description,
        thumbnail: thumbnail,
        tags: tags,
        fileIds: fileIds,
      );
      final cacheIdx =
          _postCache[spaceId]?.indexWhere((x) => x.id == postId) ?? -1;
      if (cacheIdx >= 0) _postCache[spaceId]![cacheIdx] = p;
      notifyListeners();
      return p;
    });

    final space = spaceById(spaceId);
    if (space != null) {
      _scheduleHooks(
        post: updated,
        original: previous,
        space: space,
        trigger: HookTrigger.edit,
      );
    }
  }

  Future<void> deletePost(String spaceId, String postId) async {
    await _posts.delete(spaceId, postId);
    _postCache[spaceId]?.removeWhere((x) => x.id == postId);
    _resortSpacesByUsage();
    notifyListeners();
  }

  /// Returns the raw HTML + frontmatter for [postId].
  Future<String> readPostSource(String spaceId, String postId) =>
      _posts.readSource(spaceId, postId);

  /// Returns the actual on-disk path for [postId]'s source file, or null
  /// if it can't be located (should not happen for a loaded post).
  Future<String?> postFilePath(String spaceId, String postId) =>
      _posts.filePath(spaceId, postId);

  // ── Drive ──────────────────────────────────────────────────────────────

  Future<DriveFile> addFileFromBytes({
    required String spaceId,
    required Uint8List bytes,
    required String name,
  }) async {
    final file = await _drive.addBytes(
      spaceId: spaceId,
      bytes: bytes,
      name: name,
    );
    _fileCache.putIfAbsent(spaceId, () => []).insert(0, file);
    _fileIndex.putIfAbsent(spaceId, () => {})[file.id] = file;
    notifyListeners();
    return file;
  }

  Future<Uint8List> readFileBytes(String spaceId, String fileId) =>
      _drive.readBytes(spaceId, fileId);

  Future<Uint8List> readImageBytes(String spaceId, String fileId) async {
    final key = '$spaceId:$fileId';
    final cached = _imageCache[key];
    if (cached != null) return cached;
    final bytes = await _drive.readBytes(spaceId, fileId);
    _imageCache[key] = bytes;
    return bytes;
  }

  Future<void> deleteFile(String spaceId, String fileId) async {
    await _drive.delete(spaceId, fileId);
    _fileCache[spaceId]?.removeWhere((x) => x.id == fileId);
    _fileIndex[spaceId]?.remove(fileId);
    _imageCache.remove('$spaceId:$fileId');
    _imageAspectCache.remove('$spaceId:$fileId'); // ← add
    notifyListeners();
  }

  // ── Archive (zip export / import) ──────────────────────────────────────

  Future<Uint8List> exportSpaceZip(String spaceId) =>
      _archive.exportSpace(spaceId);

  Future<String> importSpaceZip(Uint8List zipBytes) async {
    final id = await _archive.importSpace(zipBytes);
    await reload();
    return id;
  }

  Future<SpaceImportResult> importSpaceZipIntoExistingSpace({
    required String targetSpaceId,
    required Uint8List zipBytes,
  }) async {
    final extracted = await _archive.readSpaceArchive(zipBytes);

    final existingPosts = _postCache[targetSpaceId] ?? const <Post>[];
    final existingIds = {for (final p in existingPosts) p.id};
    final existingUrls = <String>{
      for (final p in existingPosts)
        if (p.kind == PostKind.bookmark && p.url != null) p.url!,
    };
    final existingFileIds = (_fileCache[targetSpaceId] ?? const <DriveFile>[])
        .map((f) => f.id)
        .toSet();

    // Posts referenced as a reply parent within the incoming batch — these
    // must be imported even if their URL matches something in the target,
    // otherwise the reply's `parent` field would point to a missing post.
    final referencedParents = <String>{
      for (final p in extracted.posts)
        if (p.parentId != null) p.parentId!,
    };

    // Decide what to import.
    final toImportPosts = <Post>[];
    var skippedDuplicates = 0;
    for (final p in extracted.posts) {
      if (existingIds.contains(p.id)) {
        skippedDuplicates++;
        continue;
      }
      if (p.kind == PostKind.bookmark &&
          p.url != null &&
          existingUrls.contains(p.url) &&
          !referencedParents.contains(p.id)) {
        skippedDuplicates++;
        continue;
      }
      toImportPosts.add(p);
    }

    // Import files first so imported posts can resolve fileIds.
    final importedFiles = await _drive.importExistingFiles(
      spaceId: targetSpaceId,
      files: extracted.files,
      existingIds: existingFileIds,
    );
    final filesSkipped = extracted.files.length - importedFiles.length;

    // Import posts.
    final importedPosts = <Post>[];
    var failedPosts = 0;
    for (final p in toImportPosts) {
      try {
        final imported =
            await _posts.importExisting(spaceId: targetSpaceId, post: p);
        importedPosts.add(imported);
      } catch (e) {
        debugPrint('Failed to import post ${p.id}: $e');
        failedPosts++;
      }
    }

    // Update caches in one shot.
    if (importedPosts.isNotEmpty) {
      final merged = [
        ...(_postCache[targetSpaceId] ?? const <Post>[]),
        ...importedPosts,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _postCache[targetSpaceId] = merged;
    }
    if (importedFiles.isNotEmpty) {
      _fileCache[targetSpaceId] = [
        ...(_fileCache[targetSpaceId] ?? const <DriveFile>[]),
        ...importedFiles,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final f in importedFiles) {
        _fileIndex.putIfAbsent(targetSpaceId, () => {})[f.id] = f;
      }
    }

    _resortSpacesByUsage();
    notifyListeners();

    return SpaceImportResult(
      total: extracted.posts.length,
      imported: importedPosts.length,
      skippedDuplicates: skippedDuplicates + failedPosts,
      filesImported: importedFiles.length,
      filesSkipped: filesSkipped,
    );
  }

  // ── Bookmark import ────────────────────────────────────────────────────

  Future<BookmarkImportResult> importBookmarksIntoSpace({
    required String spaceId,
    required BookmarkFile file,
  }) async {
    final existing = _postCache[spaceId] ?? const <Post>[];
    final existingUrls = {
      for (final p in existing)
        if (p.kind == PostKind.bookmark && p.url != null) p.url!,
    };

    final r = await _bookmarksImporter.importInto(
      spaceId: spaceId,
      bookmarks: file.bookmarks,
      existingUrls: existingUrls,
    );

    if (r.created.isNotEmpty) {
      final merged = [...existing, ...r.created]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _postCache[spaceId] = merged;
      _resortSpacesByUsage();
      notifyListeners();
    }
    return r.result;
  }

  Future<Space> importBookmarksAsNewSpace({
    required BookmarkFile file,
    required String spaceName,
    String icon = '📚',
  }) async {
    final space = await createSpace(name: spaceName, icon: icon);
    final r = await _bookmarksImporter.importInto(
      spaceId: space.id,
      bookmarks: file.bookmarks,
      existingUrls: const {},
    );
    if (r.created.isNotEmpty) {
      _postCache[space.id] = List.of(r.created)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _resortSpacesByUsage();
      notifyListeners();
    }
    return space;
  }

  // ── Metadata + stats ───────────────────────────────────────────────────

  Future<LinkMetadata?> fetchLinkMetadata(String url) => _link.fetch(url);

  Future<SpaceStats> computeStats(String spaceId) => _stats.compute(
        spaceId,
        posts: _postCache[spaceId] ?? const [],
        files: _fileCache[spaceId] ?? const [],
      );

  // ── Hooks: CRUD ────────────────────────────────────────────────────────

  Future<void> saveHook(Hook hook) async {
    await _hooks.save(hook);
    notifyListeners();
  }

  Future<void> deleteHook(String id) async {
    await _hooks.delete(id);
    notifyListeners();
  }

  /// True if at least one hook is currently running for [postId]. Used by
  /// the post card to show a spinner.
  bool hasActiveHooks(String postId) =>
      _activeHookRuns.any((k) => k.startsWith('$postId:'));

  /// Re-runs a specific hook on a post. Used by the "Re-run" button in the
  /// hook status dialog — typically after a failure, but works on successful
  /// hooks too (e.g. re-send to Telegram after manual changes on their end).
  ///
  /// `{{trigger}}` in templates resolves to `create` for never-edited posts
  /// and `edit` otherwise. The exact original trigger isn't stored, so a
  /// retried create-triggered hook on an edited post will see `edit`.
  /// Templates that don't reference `{{trigger}}` are unaffected.
  Future<void> retryHook(String spaceId, String postId, String hookKey) async {
    // Snapshot the post + hook + space. If any is missing, nothing to do.
    Post? post;
    for (final p in _postCache[spaceId] ?? const <Post>[]) {
      if (p.id == postId) {
        post = p;
        break;
      }
    }
    if (post == null) return;

    final hook = _hooks.byKey(hookKey);
    if (hook == null) {
      debugPrint('retryHook: hook "$hookKey" not found');
      return;
    }

    final space = spaceById(spaceId);
    if (space == null) return;

    Post? parentPost;
    if (post.parentId != null) {
      for (final p in _postCache[spaceId] ?? const <Post>[]) {
        if (p.id == post.parentId) {
          parentPost = p;
          break;
        }
      }
    }

    final files = post.fileIds
        .map((id) => _fileIndex[spaceId]?[id])
        .whereType<DriveFile>()
        .toList();

    final resolved = <String, ResolvedFile>{};
    Future<ResolvedFile?> resolveFile(String fileId) async {
      final cached = resolved[fileId];
      if (cached != null) return cached;
      final df = _fileIndex[spaceId]?[fileId];
      if (df == null) return null;
      final bytes = await _drive.readBytes(spaceId, fileId);
      final r = ResolvedFile(
        bytes: bytes,
        name: df.name,
        mimeType: mimeTypeForName(df.name),
      );
      resolved[fileId] = r;
      return r;
    }

    final activeKey = '$postId:$hookKey';
    _activeHookRuns.add(activeKey);
    notifyListeners();

    try {
      final result = await _executor.execute(
        hook: hook,
        post: post,
        original: null,
        parent: parentPost,
        space: space,
        trigger: post.editedAt == null ? HookTrigger.create : HookTrigger.edit,
        priorStates: post.hookState,
        parentPriorStates: parentPost?.hookState ?? const {},
        files: files,
        resolveFile: resolveFile,
      );

      await _withPostLock(postId, () async {
        final patched =
            await _posts.patchHookState(spaceId, postId, {hookKey: result});
        final idx =
            _postCache[spaceId]?.indexWhere((x) => x.id == postId) ?? -1;
        if (idx >= 0) _postCache[spaceId]![idx] = patched;
      });
    } catch (e) {
      // Post could have been deleted during the network call, or the file
      // write could have failed. Log without rethrowing so the dialog's
      // caller doesn't need to handle it.
      debugPrint('Retry failed for $hookKey on $postId: $e');
    } finally {
      _activeHookRuns.remove(activeKey);
      notifyListeners();
    }
  }

  /// Convenience: retries every failed hook on [postId] sequentially.
  /// Each call to [retryHook] goes through its own `_withPostLock`, so
  /// parallel calls would serialize on the file anyway.
  Future<void> retryFailedHooks(String spaceId, String postId) async {
    Post? post;
    for (final p in _postCache[spaceId] ?? const <Post>[]) {
      if (p.id == postId) {
        post = p;
        break;
      }
    }
    if (post == null) return;

    final failed = <String>[
      for (final e in post.hookState.entries)
        if (hookStateFailed(e.value)) e.key,
    ];
    for (final key in failed) {
      await retryHook(spaceId, postId, key);
    }
  }

  // ── Hooks: execution ───────────────────────────────────────────────────

  Future<T> _withPostLock<T>(String postId, Future<T> Function() fn) {
    final prev = _postLocks[postId] ?? Future<void>.value();
    final completer = Completer<T>();
    final next = prev.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    _postLocks[postId] = next;
    next.whenComplete(() {
      if (identical(_postLocks[postId], next)) _postLocks.remove(postId);
    });
    return completer.future;
  }

  void _scheduleHooks({
    required Post post,
    required Post? original,
    required Space space,
    required HookTrigger trigger,
  }) {
    final prev = _hookChains[post.id] ?? Future<void>.value();
    final next = prev.then((_) => _runHooks(
          postId: post.id,
          originalSnapshot: original,
          space: space,
          trigger: trigger,
        ));
    _hookChains[post.id] = next;
    next.whenComplete(() {
      if (identical(_hookChains[post.id], next)) _hookChains.remove(post.id);
    });
  }

  Future<void> _runHooks({
    required String postId,
    required Post? originalSnapshot,
    required Space space,
    required HookTrigger trigger,
  }) async {
    Post? post;
    for (final p in _postCache[space.id] ?? const <Post>[]) {
      if (p.id == postId) {
        post = p;
        break;
      }
    }
    if (post == null) return;

    Post? parentPost;
    if (post.parentId != null) {
      for (final p in _postCache[space.id] ?? const <Post>[]) {
        if (p.id == post.parentId) {
          parentPost = p;
          break;
        }
      }
    }

    final active = _hooks.activeFor(
      spaceId: space.id,
      trigger: trigger,
      postKind: post.kind,
      postTags: post.tags.toSet(),
    );
    if (active.isEmpty) return;

    final files = post.fileIds
        .map((id) => _fileIndex[space.id]?[id])
        .whereType<DriveFile>()
        .toList();

    final resolved = <String, ResolvedFile>{};
    Future<ResolvedFile?> resolveFile(String fileId) async {
      final cached = resolved[fileId];
      if (cached != null) return cached;
      final df = _fileIndex[space.id]?[fileId];
      if (df == null) return null;
      final bytes = await _drive.readBytes(space.id, fileId);
      final r = ResolvedFile(
        bytes: bytes,
        name: df.name,
        mimeType: mimeTypeForName(df.name),
      );
      resolved[fileId] = r;
      return r;
    }

    // Mark the whole batch active up front so the card shows one continuous
    // "running" state rather than flickering between individual hooks.
    for (final hook in active) {
      _activeHookRuns.add('$postId:${hook.key}');
    }
    notifyListeners();

    try {
      final priorStates = post.hookState;
      final results = <String, PostHookState>{};
      for (final hook in active) {
        results[hook.key] = await _executor.execute(
          hook: hook,
          post: post,
          original: originalSnapshot,
          parent: parentPost,
          space: space,
          trigger: trigger,
          priorStates: priorStates,
          parentPriorStates: parentPost?.hookState ?? const {},
          files: files,
          resolveFile: resolveFile,
        );
      }
      if (results.isEmpty) return;

      await _withPostLock(postId, () async {
        final patched = await _posts.patchHookState(space.id, postId, results);
        final idx =
            _postCache[space.id]?.indexWhere((x) => x.id == postId) ?? -1;
        if (idx >= 0) _postCache[space.id]![idx] = patched;
      });
    } catch (e) {
      debugPrint('Hook batch failed for $postId: $e');
    } finally {
      for (final hook in active) {
        _activeHookRuns.remove('$postId:${hook.key}');
      }
      notifyListeners();
    }
  }

  // ── Sync ───────────────────────────────────────────────────────────────

  Future<void> saveSyncConfig(SyncConfig config) async {
    final old = _cachedSyncConfig;
    if (old != null &&
        (old.provider != config.provider ||
            old.owner != config.owner ||
            old.repo != config.repo ||
            old.branch != config.branch)) {
      await _syncCacheStore.clear(old.tokenKey);
    }
    await _syncConfigStore.save(config);
    _cachedSyncConfig = config;
    notifyListeners();
  }

  Future<String?> loadSyncToken() async {
    final c = _cachedSyncConfig;
    if (c == null) return null;
    return _syncTokenStore.load(c.tokenKey);
  }

  Future<void> saveSyncToken(String token) async {
    final c = _cachedSyncConfig;
    if (c == null) throw StateError('Sync not configured');
    await _syncTokenStore.save(c.tokenKey, token);
  }

  Future<void> clearSyncToken() async {
    final c = _cachedSyncConfig;
    if (c == null) return;
    await _syncTokenStore.delete(c.tokenKey);
  }

  SyncProvider _makeProvider(http.Client client, SyncConfig config) {
    switch (config.provider) {
      case SyncProviderKind.github:
        return GitHubProvider(client: client);
      case SyncProviderKind.gitlab:
        return GitLabProvider(client: client);
    }
  }

  Future<void> verifySyncAccess() async {
    final config = _cachedSyncConfig;
    if (config == null) throw StateError('Sync not configured');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');
    final client = http.Client();
    try {
      await _makeProvider(client, config)
          .verifyAccess(config: config, token: token);
    } finally {
      client.close();
    }
  }

  Future<SyncPushResult> syncPush({
    SyncProgressCallback? onProgress,
  }) async {
    final config = _cachedSyncConfig;
    if (config == null) throw StateError('Sync not configured');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');
    final client = http.Client();
    try {
      final provider = _makeProvider(client, config);
      final service = SyncService(
        fs: fs,
        vaultPath: vaultPath,
        config: config,
        provider: provider,
        cacheStore: _syncCacheStore,
      );
      final result = await service.push(token: token, onProgress: onProgress);
      await saveSyncConfig(config.copyWith(
        lastSyncedAt: DateTime.now().toUtc(),
        lastCommitSha: result.commitSha,
      ));
      await reload();
      return result;
    } finally {
      client.close();
    }
  }

  Future<SyncPullResult> syncPull({
    SyncProgressCallback? onProgress,
  }) async {
    final config = _cachedSyncConfig;
    if (config == null) throw StateError('Sync not configured');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');

    await _backupVault();

    final client = http.Client();
    try {
      final provider = _makeProvider(client, config);
      final service = SyncService(
        fs: fs,
        vaultPath: vaultPath,
        config: config,
        provider: provider,
        cacheStore: _syncCacheStore,
      );
      final result = await service.pull(token: token, onProgress: onProgress);
      await saveSyncConfig(config.copyWith(
        lastSyncedAt: DateTime.now().toUtc(),
      ));
      await reload();
      return result;
    } finally {
      client.close();
    }
  }

  Future<void> _backupVault() async {
    if (kIsWeb) {
      throw UnsupportedError('Vault backup is not supported on web.');
    }
    final archive = Archive();
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return;
    final files = await walkFiles(root);
    for (final f in files) {
      try {
        final rel = p.relative(f.path, from: vaultPath);
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile(rel, bytes.length, bytes));
      } catch (_) {}
    }
    final supportDir = await getApplicationSupportDirectory();
    final backupDir = fs.directory(p.join(supportDir.path, 'vault_backups'));
    await backupDir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9T]'), '')
        .substring(0, 15);
    await fs
        .file(p.join(backupDir.path, 'pre-pull-$stamp.zip'))
        .writeAsBytes(Uint8List.fromList(ZipEncoder().encode(archive)!));
  }
}
