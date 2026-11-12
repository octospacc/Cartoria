import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/fs.dart';
import '../util/fs_walk.dart';
import '../util/hook_outcome.dart';
import '../util/mime.dart';
import '../util/platform.dart';
import 'app_settings.dart';
import 'bookmarks.dart';
import 'composer_draft.dart';
import 'composer_draft_store.dart';
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
import 'space_archive.dart';
import 'sync/content_fetcher.dart';
import 'sync/offloaded_store.dart';
import 'sync/sync_config.dart';
import 'sync/github_provider.dart';
import 'sync/gitlab_provider.dart';
import 'sync/sync_provider.dart';
import 'sync/sync_scope.dart';
import 'sync/sync_service.dart';
import 'thumbnail_cache.dart';

export 'repos/bookmarks_importer.dart' show BookmarkImportResult;
export 'services/link_metadata.dart' show LinkMetadata;
export 'services/space_stats.dart' show SpaceStats;
export 'space_archive.dart' show ExtractedFile, ExtractedSpace;
export 'sync/sync_provider.dart' show SyncProgress, SyncProgressCallback;
export 'sync/sync_service.dart' show SyncPushResult, SyncPullResult;
export 'app_settings.dart' show AppSettings;

class BackupInfo {
  final String name;
  final int sizeBytes;
  final DateTime modified;
  const BackupInfo({
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });
}

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
  late final SyncConfigsStore _syncConfigsStore;
  late final SyncTokenStore _syncTokenStore;
  late final SyncCacheStore _syncCacheStore;
  late final OffloadedStore _offloadedStore;
  late final ThumbnailCache _thumbnailCache;
  late final ContentFetcher _contentFetcher;

  late final AppSettingsStore _settingsStore;
  AppSettings _settings = const AppSettings();

  late final ComposerDraftStore _composerDraftStore;

  final http.Client _httpClient = http.Client();

  final List<Space> _spaceCache = [];
  final Map<String, List<Post>> _postCache = {};
  final Map<String, List<DriveFile>> _fileCache = {};
  final Map<String, Map<String, DriveFile>> _fileIndex = {};
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, double> _imageAspectCache = {};
  final Map<String, Set<String>> _offloadedIdsBySpace = {};

  final Map<String, Future<void>> _postLocks = {};
  final Map<String, Future<void>> _hookChains = {};
  final Set<String> _activeHookRuns = {};

  List<SyncConfig> _syncConfigs = [];

  /// Bounded in-memory cache of image thumbnails keyed by `spaceId:fileId`.
  /// Separate from [_imageCache] because thumbnails (~50 KB each) and
  /// full-size images (multi-MB) have completely different lifecycle
  /// profiles: thumbnails are reused heavily across scroll and evicted
  /// rarely; full images are used once per open and should be freed.
  ///
  /// 200 entries × ~50 KB ≈ 10 MB ceiling. Older entries evicted by
  /// insertion order. Cheap to regenerate from disk on the rare miss.
  final Map<String, Uint8List> _thumbBytesCache = {};
  static const int _thumbCacheMaxEntries = 200;

  /// Concurrency limit for thumbnail generation. Reading N full images
  /// in parallel defeats the point — the peak heap equals N × file size.
  /// Three in flight bounds the peak to ~3× the largest single file.
  int _thumbLoadsInFlight = 0;
  static const int _maxConcurrentThumbLoads = 3;
  final List<Completer<void>> _thumbLoadQueue = [];

  Future<void> _acquireThumbSlot() async {
    while (_thumbLoadsInFlight >= _maxConcurrentThumbLoads) {
      final c = Completer<void>();
      _thumbLoadQueue.add(c);
      await c.future;
    }
    _thumbLoadsInFlight++;
  }

  void _releaseThumbSlot() {
    _thumbLoadsInFlight--;
    if (_thumbLoadQueue.isNotEmpty) {
      _thumbLoadQueue.removeAt(0).complete();
    }
  }

  void _trimThumbCache() {
    while (_thumbBytesCache.length > _thumbCacheMaxEntries) {
      _thumbBytesCache.remove(_thumbBytesCache.keys.first);
    }
  }

  /// Returns a downscaled thumbnail for [fileId]. Safe to call for every
  /// visible tile in a grid — bounded concurrency and cache prevent the
  /// peak memory from exceeding a few MB regardless of file count.
  ///
  /// Caching strategy differs by file state:
  ///  - Offloaded: SHA-addressed disk cache (deduplicated across files).
  ///  - Local: in-memory map keyed by fileId, bounded above.
  Future<Uint8List> readImageThumbnail(String spaceId, String fileId) async {
    if (offloadedFileIds(spaceId).contains(fileId)) {
      return fetchThumbnailForOffloaded(spaceId, fileId);
    }

    final key = '$spaceId:$fileId';
    final cached = _thumbBytesCache[key];
    if (cached != null) return cached;

    await _acquireThumbSlot();
    try {
      // Re-check inside the slot — a concurrent load may have populated it.
      final recheck = _thumbBytesCache[key];
      if (recheck != null) return recheck;

      final full = await _drive.readBytes(spaceId, fileId);
      final thumb = await _makeThumbnail(full);
      _thumbBytesCache[key] = thumb;
      _trimThumbCache();
      return thumb;
    } finally {
      _releaseThumbSlot();
    }
  }

  // ── Read accessors ─────────────────────────────────────────────────────

  /// True once the user has either created a space or explicitly skipped
  /// the welcome screen. When true, the welcome screen never shows again,
  /// even if every space is deleted.
  bool get isOnboarded => _settings.onboarded;

  List<Space> get spaces => List.unmodifiable(_spaceCache);
  List<Post> postsForSpace(String spaceId) =>
      List.unmodifiable(_postCache[spaceId] ?? const <Post>[]);
  List<DriveFile> filesForSpace(String spaceId) =>
      List.unmodifiable(_fileCache[spaceId] ?? const <DriveFile>[]);
  List<Hook> get hooks => _hooks.all;

  List<SyncConfig> get syncConfigs => List.unmodifiable(_syncConfigs);
  SyncConfig? get primarySyncConfig {
    for (final c in _syncConfigs) {
      if (c.isPrimary) return c;
    }
    return null;
  }

  SyncConfig? syncConfigById(String id) {
    for (final c in _syncConfigs) {
      if (c.id == id) return c;
    }
    return null;
  }

  Space? spaceById(String id) {
    for (final s in _spaceCache) {
      if (s.id == id) return s;
    }
    return null;
  }

  DriveFile? fileById(String spaceId, String fileId) =>
      _fileIndex[spaceId]?[fileId];

  Set<String> offloadedFileIds(String spaceId) =>
      _offloadedIdsBySpace[spaceId] ?? const {};

  Future<OffloadedFileInfo?> offloadedInfoFor(String spaceId, String fileId) =>
      _offloadedStore.get(spaceId, fileId);

  ThumbnailCache get thumbnailCache => _thumbnailCache;

  bool hasActiveHooks(String postId) =>
      _activeHookRuns.any((k) => k.startsWith('$postId:'));

  void _rebuildFileIndex(String spaceId) {
    _fileIndex[spaceId] = {
      for (final f in _fileCache[spaceId] ?? const <DriveFile>[]) f.id: f,
    };
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  Future<void> init() async {
    fs = createFs();
    if (kIsWeb) {
      vaultPath = '/Cartoria';
    } else {
      final docs = await getApplicationDocumentsDirectory();
      vaultPath = p.join(docs.path, 'Cartoria');
    }

    _spaces = SpaceRepository(fs: fs, vaultPath: vaultPath);
    _posts = PostRepository(fs: fs, vaultPath: vaultPath);
    _drive = DriveRepository(fs: fs, vaultPath: vaultPath);
    _archive = ArchiveService(fs: fs, vaultPath: vaultPath);
    _stats = SpaceStatsCalculator(fs: fs, vaultPath: vaultPath);
    _hooks = HooksRepository(fs: fs, vaultPath: vaultPath);
    _executor = HookExecutor(client: _httpClient);
    _bookmarksImporter = BookmarksImporter(posts: _posts);
    _syncConfigsStore = SyncConfigsStore(fs: fs, vaultPath: vaultPath);
    _syncTokenStore = SyncTokenStore(fs: fs);
    _syncCacheStore = SyncCacheStore(fs: fs);
    _offloadedStore = const OffloadedStore();
    _thumbnailCache = const ThumbnailCache();
    _composerDraftStore = const ComposerDraftStore();
    _link = LinkMetadataService(
      proxyUrl: kIsWeb ? 'https://corsproxy.io/?url={url}' : null,
    );

    _drive.offloadedStore = _offloadedStore;
    _contentFetcher = ContentFetcher(this);
    _drive.onFetchBytes =
        (spaceId, fileId) => _contentFetcher.fetch(spaceId, fileId);

    await fs.directory(vaultPath).create(recursive: true);

    try {
      _syncConfigs = await _syncConfigsStore.load();
    } catch (e) {
      debugPrint('Sync configs load failed: $e');
      _syncConfigs = [];
    }

    _settingsStore = AppSettingsStore(fs: fs, vaultPath: vaultPath);
    try {
      _settings = await _settingsStore.load();
    } catch (e) {
      debugPrint('Settings load failed: $e');
      _settings = const AppSettings();
    }

    // This should be called after the vaultPath is determined.
    if (isNativeAndroid) {
      try {
        const channel = MethodChannel('cartoria/documents_provider');
        await channel.invokeMethod<void>(
          'setVaultPath',
          {'path': vaultPath},
        );
      } catch (e) {
        debugPrint('Could not register vault path with DocumentsProvider: $e');
      }
    }

    await reload();
  }

  @override
  void dispose() {
    _contentFetcher.dispose();
    _httpClient.close();
    super.dispose();
  }

  Future<void> reload() async {
    await _migratePostFolders();
    await _spaces.migrateHtmlToJson();
    await _hooks.migrateSingleFileToFolder();

    // Hooks can change on disk without going through HooksRepository —
    // git pull writes hook files directly via the filesystem, bypassing
    // the repo's in-memory cache. Reloading here keeps the hooks screen
    // and hook matching in sync with whatever is actually on disk.
    //
    // Wrapped because reload() is a hot path (called after every
    // non-trivial pull); a malformed hook should not abort the whole
    // refresh. HooksRepository.load() already tolerates individual
    // malformed files, so this only guards against filesystem errors.
    try {
      await _hooks.load();
    } catch (e) {
      debugPrint('Hooks reload failed: $e');
    }

    _drive.clearCache();
    _spaceCache.clear();
    _postCache.clear();
    _fileCache.clear();
    _fileIndex.clear();
    _imageAspectCache.clear();
    _offloadedIdsBySpace.clear();

    final spaces = await _spaces.list();
    for (final space in spaces) {
      _spaceCache.add(space);
      try {
        _postCache[space.id] = await _posts.list(space.id);
        _fileCache[space.id] = await _drive.list(space.id);
        _rebuildFileIndex(space.id);
        _offloadedIdsBySpace[space.id] =
            (await _offloadedStore.load(space.id)).keys.toSet();
      } catch (e) {
        debugPrint('Failed to load space ${space.id}: $e');
        _postCache[space.id] = [];
        _fileCache[space.id] = [];
        _fileIndex[space.id] = {};
      }
      // Yield between spaces so GC can reclaim the previous space's parsed
      // objects before the next one starts. Small cost (~5ms per space),
      // large benefit on web when there are many posts to re-parse.
      if (kIsWeb) await Future<void>.delayed(Duration.zero);
    }

    // Backfill the onboarding flag for users upgrading from a version that
    // predates it. Anyone with at least one space has clearly used the app.
    if (_spaceCache.isNotEmpty && !_settings.onboarded) {
      _settings = const AppSettings(onboarded: true);
      try {
        await _settingsStore.save(_settings);
      } catch (e) {
        debugPrint('Could not persist onboarding flag: $e');
      }
    }

    _resortSpacesByUsage();
    notifyListeners();
  }

  // ── Spaces ─────────────────────────────────────────────────────────────

  Future<Space> createSpace({required String name, String icon = '📓'}) async {
    final space = await _spaces.create(name: name, icon: icon);
    _spaceCache.insert(0, space);
    _postCache[space.id] = [];
    _fileCache[space.id] = [];
    _fileIndex[space.id] = {};
    _offloadedIdsBySpace[space.id] = {};
    _resortSpacesByUsage();

    // Creating a space is an implicit "I'm done with onboarding" signal.
    if (!_settings.onboarded) {
      _settings = const AppSettings(onboarded: true);
      try {
        await _settingsStore.save(_settings);
      } catch (e) {
        debugPrint('Could not persist onboarding flag: $e');
      }
    }

    notifyListeners();
    return space;
  }

  Future<void> updateSpace(String spaceId,
      {required String name, required String icon}) async {
    final updated =
        await _spaces.update(spaceId: spaceId, name: name, icon: icon);
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
    _offloadedIdsBySpace.remove(spaceId);
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
    DateTime? createdAt,
    String? quotedPostId,
    bool skipHooks = false,
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
      createdAt: createdAt,
      quotedPostId: quotedPostId,
    );
    _postCache.putIfAbsent(spaceId, () => []).add(post);
    _postCache[spaceId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _resortSpacesByUsage();
    notifyListeners();

    if (!skipHooks) {
      final space = spaceById(spaceId);
      if (space != null) {
        _scheduleHooks(
          post: post,
          original: null,
          space: space,
          trigger: HookTrigger.create,
        );
      }
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
    bool skipHooks = false,
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

    if (!skipHooks) {
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
  }

  Future<void> deletePost(String spaceId, String postId) async {
    await _posts.delete(spaceId, postId);
    _postCache[spaceId]?.removeWhere((x) => x.id == postId);
    _resortSpacesByUsage();
    notifyListeners();
  }

  Future<void> deletePosts(String spaceId, Set<String> postIds) async {
    if (postIds.isEmpty) return;
    await _posts.deleteMultiple(spaceId, postIds);
    _postCache[spaceId]?.removeWhere((p) => postIds.contains(p.id));
    _resortSpacesByUsage();
    notifyListeners();
  }

  Future<String> readPostSource(String spaceId, String postId) =>
      _posts.readSource(spaceId, postId);

  Future<String?> postFilePath(String spaceId, String postId) =>
      _posts.filePath(spaceId, postId);

  // ── Drive ──────────────────────────────────────────────────────────────

  Future<DriveFile> addFileFromBytes({
    required String spaceId,
    required Uint8List bytes,
    required String name,
  }) async {
    final file =
        await _drive.addBytes(spaceId: spaceId, bytes: bytes, name: name);
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
    _offloadedIdsBySpace[spaceId]?.remove(fileId);
    _imageCache.remove('$spaceId:$fileId');
    _imageAspectCache.remove('$spaceId:$fileId');
    _thumbBytesCache.remove('$spaceId:$fileId');
    notifyListeners();
  }

  Future<void> deleteFiles(String spaceId, Set<String> fileIds) async {
    if (fileIds.isEmpty) return;
    await _drive.deleteMultiple(spaceId, fileIds);
    _fileCache[spaceId]?.removeWhere((f) => fileIds.contains(f.id));
    for (final id in fileIds) {
      _fileIndex[spaceId]?.remove(id);
      _offloadedIdsBySpace[spaceId]?.remove(id);
      _imageCache.remove('$spaceId:$id');
      _imageAspectCache.remove('$spaceId:$id');
      _thumbBytesCache.remove('$spaceId:$id');
    }
    notifyListeners();
  }

  double? imageAspectRatio(String spaceId, String fileId) =>
      _imageAspectCache['$spaceId:$fileId'];

  void cacheImageAspect(String spaceId, String fileId, double ratio) {
    if (ratio <= 0 || !ratio.isFinite) return;
    _imageAspectCache['$spaceId:$fileId'] = ratio;
  }

  // ── Offloading ─────────────────────────────────────────────────────────

  Set<String> usedFileIds(String spaceId) {
    final used = <String>{};
    for (final post in _postCache[spaceId] ?? const <Post>[]) {
      if (post.fileIds.isNotEmpty) used.addAll(post.fileIds);
    }
    return used;
  }

  /// Fills in a missing file's slot with bytes picked by the user.
  /// See [DriveRepository.restoreMissingFile] for the semantics.
  Future<void> restoreMissingFile({
    required String spaceId,
    required String fileId,
    required Uint8List bytes,
    required String name,
  }) async {
    final restored = await _drive.restoreMissingFile(
      spaceId: spaceId,
      fileId: fileId,
      bytes: bytes,
      name: name,
    );

    // Update the file cache and index with the new DriveFile (isMissing
    // becomes false because the default constructor sets it false).
    final idx = _fileCache[spaceId]?.indexWhere((f) => f.id == fileId) ?? -1;
    if (idx >= 0) {
      _fileCache[spaceId]![idx] = restored;
    }
    _fileIndex[spaceId]?[fileId] = restored;

    // Any stale caches from failed loads must be cleared.
    _imageCache.remove('$spaceId:$fileId');
    _imageAspectCache.remove('$spaceId:$fileId');
    _thumbBytesCache.remove('$spaceId:$fileId');

    notifyListeners();
  }

  Future<void> fetchOffloadedFile(String spaceId, String fileId) async {
    // 1. Fetch bytes (via `_drive.readBytes`, which delegates to
    //    ContentFetcher because the file is offloaded).
    final bytes = await _drive.readBytes(spaceId, fileId);

    // 2. Write to disk and unoffload. `restoreFile` also updates the
    //    path cache so subsequent reads don't hit the stale-index bug.
    await _drive.restoreFile(spaceId, fileId, bytes);

    // 3. Reload the offloaded set from the store (source of truth).
    //    This is the safest way to avoid drift between the in-memory set
    //    and the on-disk record.
    final offloaded = await _offloadedStore.load(spaceId);
    _offloadedIdsBySpace[spaceId] = offloaded.keys.toSet();

    // 4. Update in-memory caches.
    _imageCache['$spaceId:$fileId'] = bytes;

    final file = _fileIndex[spaceId]?[fileId];
    if (file != null) {
      final updated = DriveFile(
        id: file.id,
        name: file.name,
        sizeBytes: bytes.length,
        createdAt: file.createdAt,
      );
      _fileIndex[spaceId]![fileId] = updated;
      final idx = _fileCache[spaceId]?.indexWhere((f) => f.id == fileId) ?? -1;
      if (idx >= 0) _fileCache[spaceId]![idx] = updated;
    }

    notifyListeners();
  }

  Future<Uint8List> fetchThumbnailForOffloaded(
      String spaceId, String fileId) async {
    final info = await _offloadedStore.get(spaceId, fileId);
    if (info == null) throw StateError('File $fileId is not offloaded');

    final cached = await _thumbnailCache.get(info.remoteSha);
    if (cached != null) return cached;

    final full = await _drive.readBytes(spaceId, fileId);
    final thumb = await _makeThumbnail(full);
    await _thumbnailCache.put(info.remoteSha, thumb);
    return thumb;
  }

  Future<Uint8List> _makeThumbnail(Uint8List full) async {
    try {
      final codec = await ui.instantiateImageCodec(full);
      final frame = await codec.getNextFrame();
      final srcW = frame.image.width;
      final srcH = frame.image.height;

      const maxDim = 256;

      // Already small enough — re-encode as-is.
      if (srcW <= maxDim && srcH <= maxDim) {
        final byteData =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        codec.dispose();
        return byteData!.buffer.asUint8List();
      }

      // Compute target dimensions preserving aspect.
      int targetW, targetH;
      if (srcW >= srcH) {
        targetW = maxDim;
        targetH = (maxDim * srcH / srcW).round().clamp(1, maxDim);
      } else {
        targetH = maxDim;
        targetW = (maxDim * srcW / srcH).round().clamp(1, maxDim);
      }

      // Draw at the computed size. Because targetW / targetH equals
      // srcW / srcH to within rounding, drawImageRect scales without
      // distorting — the previous codec-based call produced a square
      // output for any input and was the source of the stretching.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        frame.image,
        ui.Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final scaled = await picture.toImage(targetW, targetH);
      final byteData = await scaled.toByteData(format: ui.ImageByteFormat.png);

      frame.image.dispose();
      scaled.dispose();
      picture.dispose();
      codec.dispose();
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      return full;
    }
  }

  // ── Archive (zip export / import) ──────────────────────────────────────

  Future<Uint8List> exportSpaceZip(
    String spaceId, {
    ExportMediaMode mode = ExportMediaMode.full,
  }) async {
    final offloadedBlobs = <String, Uint8List>{};

    if (mode == ExportMediaMode.full) {
      final offloaded = _offloadedIdsBySpace[spaceId] ?? const <String>{};
      for (final fileId in offloaded) {
        try {
          offloadedBlobs[fileId] = await _drive.readBytes(spaceId, fileId);
        } catch (e) {
          throw StateError(
              'Could not fetch offloaded file $fileId for full export. '
              'Check the sync config and token, or export with a mode '
              'that skips offloaded files.');
        }
      }
    }

    return _archive.exportSpace(
      spaceId,
      mode: mode,
      offloadedBlobs: offloadedBlobs,
    );
  }

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
    // Missing files aren't considered existing — re-importing a full zip
    // must be able to fill in their blobs. Only truly-present files
    // (on-disk or offloaded) are skipped.
    final existingFileIds = <String>{
      for (final f in _fileCache[targetSpaceId] ?? const <DriveFile>[])
        if (!f.isMissing) f.id,
    };

    final referencedParents = <String>{
      for (final p in extracted.posts)
        if (p.parentId != null) p.parentId!,
    };

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

    final importedFiles = await _drive.importExistingFiles(
      spaceId: targetSpaceId,
      files: extracted.files,
      driveMeta: extracted.driveMeta, // ← add this line
      existingIds: existingFileIds,
    );
    final filesSkipped = extracted.files.length - importedFiles.length;

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
        existingUrls: existingUrls);
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
        spaceId: space.id, bookmarks: file.bookmarks, existingUrls: const {});
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

  // ── Hooks: CRUD + execution ────────────────────────────────────────────

  Future<void> saveHook(Hook hook) async {
    await _hooks.save(hook);
    notifyListeners();
  }

  Future<void> deleteHook(String id) async {
    await _hooks.delete(id);
    notifyListeners();
  }

  /// Marks the user as having completed onboarding. Called by the Skip
  /// button on the welcome screen. Idempotent.
  Future<void> markOnboarded() async {
    if (_settings.onboarded) return;
    _settings = const AppSettings(onboarded: true);
    try {
      await _settingsStore.save(_settings);
    } catch (e) {
      debugPrint('Could not persist onboarding flag: $e');
    }
    notifyListeners();
  }

  Future<ComposerDraft?> loadComposerDraft(String fieldKey) =>
      _composerDraftStore.load(fieldKey);

  Future<void> saveComposerDraft(ComposerDraft draft) =>
      _composerDraftStore.save(draft);

  Future<void> deleteComposerDraft(String fieldKey) =>
      _composerDraftStore.delete(fieldKey);

  /// The retention count actually in effect: user override if set,
  /// otherwise a platform default (10 on desktop, 3 on web — web backups
  /// go into IndexedDB and share space with the vault).
  int get effectiveBackupRetentionCount =>
      _settings.backupRetentionCount ?? (kIsWeb ? 3 : 10);

  /// The user's explicit override, or null when using the default.
  int? get backupRetentionCountOverride => _settings.backupRetentionCount;

  /// Updates the backup retention count. Null resets to the platform
  /// default. Zero disables pre-pull backups entirely. Prunes existing
  /// backups immediately if the new count is lower than the current one.
  Future<void> setBackupRetentionCount(int? count) async {
    if (count != null && count < 0) {
      throw ArgumentError('Retention count cannot be negative');
    }
    if (count != null && count > 100) {
      throw ArgumentError('Retention count cannot exceed 100');
    }
    _settings = _settings.copyWith(backupRetentionCount: count);
    try {
      await _settingsStore.save(_settings);
    } catch (e) {
      debugPrint('Could not persist backup retention: $e');
    }
    // Prune immediately so lowering the count has visible effect.
    await _pruneOldBackups(await _backupDir(),
        keep: effectiveBackupRetentionCount);
    notifyListeners();
  }

  /// Lists the pre-pull backup zips, newest first.
  Future<List<BackupInfo>> listBackups() async {
    final dir = await _backupDir();
    if (!await dir.exists()) return const [];
    final result = <BackupInfo>[];
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File || !e.path.endsWith('.zip')) continue;
        try {
          final stat = await e.stat();
          result.add(BackupInfo(
            name: p.basename(e.path),
            sizeBytes: stat.size,
            modified: stat.modified,
          ));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error listing backups: $e');
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  /// Deletes every pre-pull backup zip. Current vault data is untouched.
  Future<void> clearAllBackups() async {
    final dir = await _backupDir();
    if (!await dir.exists()) return;
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File || !e.path.endsWith('.zip')) continue;
        try {
          await e.delete();
        } catch (err) {
          debugPrint('Could not delete backup ${e.path}: $err');
        }
      }
    } catch (e) {
      debugPrint('Error clearing backups: $e');
    }
    notifyListeners();
  }

  /// Resolves the platform-specific backup directory.
  Future<Directory> _backupDir() async {
    if (kIsWeb) return fs.directory('/pre-pull-backups');
    final supportDir = await getApplicationSupportDirectory();
    return fs.directory(p.join(supportDir.path, 'vault_backups'));
  }

  /// Reads a single backup's bytes. Used by the settings screen's
  /// per-row Export action, which hands the bytes to `saveOrShareFile`
  /// (native save dialog on desktop, share sheet on mobile, download on
  /// web).
  ///
  /// Name is sanitised via `p.basename` and a `..` check before use —
  /// callers come from `listBackups()` in practice, but a defensive
  /// boundary here means a future caller can't traverse out of the
  /// backup directory.
  Future<Uint8List> readBackupBytes(String name) async {
    final safeName = p.basename(name);
    if (safeName != name || name.contains('..')) {
      throw ArgumentError('Invalid backup name');
    }
    final dir = await _backupDir();
    final file = fs.file(p.join(dir.path, safeName));
    if (!await file.exists()) {
      throw StateError('Backup $safeName not found');
    }
    return file.readAsBytes();
  }

  /// Deletes a single backup by name. Other backups and current vault
  /// data are untouched.
  Future<void> deleteBackup(String name) async {
    final safeName = p.basename(name);
    if (safeName != name || name.contains('..')) {
      throw ArgumentError('Invalid backup name');
    }
    final dir = await _backupDir();
    final file = fs.file(p.join(dir.path, safeName));
    if (await file.exists()) {
      await file.delete();
    }
    notifyListeners();
  }

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
        trigger: trigger));
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
        postTags: post.tags.toSet());
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
          bytes: bytes, name: df.name, mimeType: mimeTypeForName(df.name));
      resolved[fileId] = r;
      return r;
    }

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
            resolveFile: resolveFile);
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

  /// Returns all enabled hooks whose space/kind/tag filters match [post].
  /// Trigger filters are ignored here — the manual-run UI lets the user
  /// fire a hook regardless of which lifecycle event would have triggered
  /// it, and the appropriate trigger value is chosen per-hook at
  /// execution time (see [retryHook]).
  List<Hook> applicableHooksFor(String spaceId, String postId) {
    Post? found;
    for (final p in _postCache[spaceId] ?? const <Post>[]) {
      if (p.id == postId) {
        found = p;
        break;
      }
    }
    if (found == null) return const [];
    final post = found;
    final space = spaceById(spaceId);
    if (space == null) return const [];

    return _hooks.all.where((h) {
      if (!h.enabled) return false;
      if (h.spaceIds.isNotEmpty && !h.spaceIds.contains(space.id)) {
        return false;
      }
      if (h.postKinds.isNotEmpty && !h.postKinds.contains(post.kind)) {
        return false;
      }
      if (h.tagFilters.isNotEmpty &&
          !h.tagFilters.any((t) => post.tags.contains(t))) {
        return false;
      }
      if (h.triggers.isEmpty) return false;
      return true;
    }).toList();
  }

  HookTrigger _triggerForManualRun(Hook hook, Post post) {
    final preferred =
        post.editedAt == null ? HookTrigger.create : HookTrigger.edit;
    if (hook.triggers.contains(preferred)) return preferred;
    return hook.triggers.first;
  }

  Future<void> retryHook(String spaceId, String postId, String hookKey) async {
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
          bytes: bytes, name: df.name, mimeType: mimeTypeForName(df.name));
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
          trigger: _triggerForManualRun(hook, post),
          priorStates: post.hookState,
          parentPriorStates: parentPost?.hookState ?? const {},
          files: files,
          resolveFile: resolveFile);

      await _withPostLock(postId, () async {
        final patched =
            await _posts.patchHookState(spaceId, postId, {hookKey: result});
        final idx =
            _postCache[spaceId]?.indexWhere((x) => x.id == postId) ?? -1;
        if (idx >= 0) _postCache[spaceId]![idx] = patched;
      });
    } catch (e) {
      debugPrint('Retry failed for $hookKey on $postId: $e');
    } finally {
      _activeHookRuns.remove(activeKey);
      notifyListeners();
    }
  }

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

  // ── Sync config ────────────────────────────────────────────────────────

  Future<void> saveSyncConfig(SyncConfig config) async {
    final old = syncConfigById(config.id);
    if (old != null && old.cacheKey != config.cacheKey) {
      try {
        await _syncCacheStore.clear(old.cacheKey);
      } catch (_) {}
    }
    if (_syncConfigs.isEmpty) {
      config = config.copyWith(isPrimary: true);
    }
    final idx = _syncConfigs.indexWhere((c) => c.id == config.id);
    if (idx >= 0) {
      _syncConfigs[idx] = config;
    } else {
      _syncConfigs.add(config);
    }
    if (config.isPrimary) {
      for (var i = 0; i < _syncConfigs.length; i++) {
        if (_syncConfigs[i].id != config.id && _syncConfigs[i].isPrimary) {
          _syncConfigs[i] = _syncConfigs[i].copyWith(isPrimary: false);
        }
      }
    } else if (!_syncConfigs.any((c) => c.isPrimary)) {
      _syncConfigs[0] = _syncConfigs[0].copyWith(isPrimary: true);
    }
    await _syncConfigsStore.save(_syncConfigs);
    notifyListeners();
  }

  Future<void> removeSyncConfig(String id) async {
    final config = syncConfigById(id);
    if (config == null) return;
    final wasPrimary = config.isPrimary;
    _syncConfigs.removeWhere((c) => c.id == id);
    if (wasPrimary && _syncConfigs.isNotEmpty) {
      _syncConfigs[0] = _syncConfigs[0].copyWith(isPrimary: true);
    }
    await _syncConfigsStore.save(_syncConfigs);
    try {
      await _syncCacheStore.clear(config.cacheKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<String?> loadSyncToken(String configId) async {
    final c = syncConfigById(configId);
    if (c == null) return null;
    return _syncTokenStore.load(c.tokenKey);
  }

  Future<void> saveSyncToken(String configId, String token) async {
    final c = syncConfigById(configId);
    if (c == null) throw StateError('Sync config not found');
    await _syncTokenStore.save(c.tokenKey, token);
  }

  Future<void> clearSyncToken(String configId) async {
    final c = syncConfigById(configId);
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

  /// Fetches the set of spaces that exist in [configId]'s remote
  /// repository, keyed by space ID, with each space's display name
  /// (nullable when the metadata file couldn't be read).
  Future<Map<String, String?>> listRemoteSpaces(String configId) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');
    final client = http.Client();
    try {
      return await _makeProvider(client, config)
          .listRemoteSpaces(config: config, token: token);
    } finally {
      client.close();
    }
  }

  Future<void> verifySyncAccess(String configId) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
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

  Future<SyncPushResult> syncPush(
    String configId, {
    SyncProgressCallback? onProgress,
  }) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');
    final client = http.Client();
    try {
      final provider = _makeProvider(client, config);
      final scope = SyncScope.forConfig(config);
      final service = SyncService(
          fs: fs,
          vaultPath: vaultPath,
          config: config,
          provider: provider,
          cacheStore: _syncCacheStore,
          scope: scope);
      final result = await service.push(
          token: token,
          onProgress: onProgress,
          offloadedStore: _offloadedStore);
      await saveSyncConfig(config.copyWith(
          lastSyncedAt: DateTime.now().toUtc(),
          lastCommitSha: result.commitSha));
      return result;
    } finally {
      client.close();
    }
  }

  Future<SyncPullResult> syncPull(
    String configId, {
    SyncProgressCallback? onProgress,
  }) async {
    final config = syncConfigById(configId);
    if (config == null) throw StateError('Sync config not found');
    final token = await _syncTokenStore.load(config.tokenKey);
    if (token == null) throw StateError('Sync token not set');

    await _backupVault();

    final client = http.Client();
    try {
      final provider = _makeProvider(client, config);
      final scope = SyncScope.forConfig(config);
      final service = SyncService(
          fs: fs,
          vaultPath: vaultPath,
          config: config,
          provider: provider,
          cacheStore: _syncCacheStore,
          scope: scope);
      clearImageCacheForSync();
      final result = await service.pull(
          token: token,
          onProgress: onProgress,
          offloadedStore: _offloadedStore);
      await saveSyncConfig(config.copyWith(
        lastSyncedAt: DateTime.now().toUtc(),
      ));

      final changed =
          result.pulled > 0 || result.deleted > 0 || result.offloaded > 0;
      if (changed) {
        await reload();
        clearImageCacheForSync(); // see Fix D
      } else {
        notifyListeners();
      }
      return result;
    } finally {
      client.close();
    }
  }

  Future<void> _backupVault() async {
    final retention = effectiveBackupRetentionCount;
    // retention == 0 means "don't create pre-pull backups".
    if (retention <= 0) return;

    final archive = Archive();
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return;
    final files = await walkFiles(root);
    for (final f in files) {
      try {
        final rel = p.relative(f.path, from: vaultPath);
        // On web, skip drive blobs — they're recoverable from the remote
        // and dominate the memory budget when compressed in-memory.
        if (kIsWeb && _isDriveBlob(rel)) continue;
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile(rel, bytes.length, bytes));
        if (kIsWeb) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      } catch (_) {}
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9T]'), '')
        .substring(0, 15);
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    final backupDir = await _backupDir();
    await backupDir.create(recursive: true);
    await fs
        .file(p.join(backupDir.path, 'pre-pull-$stamp.zip'))
        .writeAsBytes(zipBytes);
    debugPrint('Pre-pull backup: '
        '${(zipBytes.length / 1024).toStringAsFixed(0)} KB, '
        '${archive.files.length} file(s)');

    await _pruneOldBackups(backupDir, keep: retention);
  }

  /// True if [relPath] is a drive blob (the binary file under
  /// `<spaceId>/drive/`), as opposed to drive_meta.json or any other file.
  bool _isDriveBlob(String relPath) {
    // Path shape: "<spaceId>/drive/<fileId>[.<ext>]"
    // The drive directory itself is one level deep.
    final parts = relPath.split('/');
    if (parts.length != 3) return false;
    return parts[1] == 'drive';
  }

  Future<void> _pruneOldBackups(Directory dir, {required int keep}) async {
    try {
      final entries = <File>[];
      await for (final e in dir.list(followLinks: false)) {
        if (e is File && e.path.endsWith('.zip')) entries.add(e);
      }
      if (entries.length <= keep) return;

      final stats = <({File f, DateTime modified})>[];
      for (final f in entries) {
        try {
          stats.add((f: f, modified: (await f.stat()).modified));
        } catch (_) {}
      }
      stats.sort((a, b) => a.modified.compareTo(b.modified));
      final toDelete = stats.take(stats.length - keep);
      for (final s in toDelete) {
        try {
          await s.f.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Backup pruning failed: $e');
    }
  }

  // ── Usage ordering ─────────────────────────────────────────────────────

  void _resortSpacesByUsage() {
    _spaceCache.sort((a, b) => _lastUsedAt(b).compareTo(_lastUsedAt(a)));
  }

  DateTime _lastUsedAt(Space space) {
    var max = space.createdAt;
    for (final p in _postCache[space.id] ?? const <Post>[]) {
      if (p.createdAt.isAfter(max)) max = p.createdAt;
    }
    return max;
  }

  /// Frees full-resolution image bytes cached from browsing. Pull can be
  /// memory-intensive on web; reclaiming these before starting gives the
  /// sync path the full tab budget. Images reload on next view — slightly
  /// slower afterwards, but pull stops crashing.
  ///
  /// The thumbnail cache is intentionally NOT cleared: it's bounded to
  /// ~10 MB and regenerating it costs more than the memory it reclaims.
  void clearImageCacheForSync() {
    _imageCache.clear();
    notifyListeners();
  }

  // ── Migrations ─────────────────────────────────────────────────────────

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
        debugPrint('Both posts/ and entries/ in ${e.path}; keeping both');
        continue;
      }
      pending.add(oldDir);
    }
    for (final oldDir in pending) {
      try {
        await oldDir.rename(p.join(p.dirname(oldDir.path), 'entries'));
      } catch (err) {
        debugPrint('Migration posts/→entries/ failed for ${oldDir.path}: $err');
      }
    }
  }

  /// Ensures the file is on local disk, downloading it from the sync
  /// remote if it's currently offloaded. Returns once the file is
  /// present on disk. No-op for files that are already local.
  Future<void> ensureFileLocal(String spaceId, String fileId) async {
    if (!offloadedFileIds(spaceId).contains(fileId)) return;
    await fetchOffloadedFile(spaceId, fileId);
  }
}
