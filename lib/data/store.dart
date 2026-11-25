library vault_store;

import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui' show Locale;

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
import 'html_image_cache.dart';
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

part 'store/drive.dart';
part 'store/sync.dart';
part 'store/backups.dart';
part 'store/archive.dart';

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

  /// Disk-backed (desktop/mobile) / in-memory (web) cache for images
  /// referenced from post HTML bodies. Used by `PostBodyText` to avoid
  /// re-fetching the same image every time its post scrolls back into
  /// view. Bounded internally; no manual management needed.
  final HtmlImageCache htmlImageCache = HtmlImageCache();

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

  ThumbnailCache get thumbnailCache => _thumbnailCache;

  bool hasActiveHooks(String postId) =>
      _activeHookRuns.any((k) => k.startsWith('$postId:'));

  void _rebuildFileIndex(String spaceId) {
    _fileIndex[spaceId] = {
      for (final f in _fileCache[spaceId] ?? const <DriveFile>[]) f.id: f,
    };
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Internal-only entry point for [notifyListeners], which is
  /// `@protected` on [ChangeNotifier] and therefore inaccessible from
  /// extensions even within the same library. All extensions on
  /// [VaultStore] (`DriveOps`, and future `SyncOps` / `BackupOps` /
  /// `ArchiveOps`) use this; the class body continues to call
  /// `notifyListeners()` directly.
  void notifyInternal() => notifyListeners();

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
    String? bodyHtml,
    String? url,
    String? title,
    String? description,
    String? thumbnail,
    String? parentId,
    List<String> tags = const [],
    List<String> fileIds = const [],
    DateTime? createdAt,
    String? quotedPostId,
    String? quotedSpaceId,
    bool skipHooks = false,
  }) async {
    final post = await _posts.create(
      spaceId: spaceId,
      kind: kind,
      plaintextBody: plaintextBody,
      bodyHtml: bodyHtml,
      url: url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      parentId: parentId,
      tags: tags,
      fileIds: fileIds,
      createdAt: createdAt,
      quotedPostId: quotedPostId,
      quotedSpaceId: quotedSpaceId,
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
    String? bodyHtml,
    String? url,
    String? title,
    String? description,
    String? thumbnail,
    List<String> tags = const [],
    List<String> fileIds = const [],
    String? quotedSpaceId,
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
        bodyHtml: bodyHtml,
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

  /// The user's selected language, or null to follow the system locale.
  /// A null value is what `MaterialApp.locale` expects to mean "use the
  /// device default", so this is passed through as-is.
  Locale? get locale {
    final code = _settings.localeCode;
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  /// Persists a language preference. Pass null to fall back to the system
  /// locale. Idempotent — a no-op if [code] matches the current setting.
  Future<void> setLocale(String? code) async {
    if (_settings.localeCode == code) return;
    _settings = _settings.copyWith(localeCode: code);
    try {
      await _settingsStore.save(_settings);
    } catch (e) {
      debugPrint('Could not persist locale: $e');
    }
    notifyListeners();
  }

  bool get richEditorEnabled => _settings.richEditorEnabled;

  Future<void> setRichEditorEnabled(bool enabled) async {
    if (_settings.richEditorEnabled == enabled) return;
    _settings = _settings.copyWith(richEditorEnabled: enabled);
    try {
      await _settingsStore.save(_settings);
    } catch (e) {
      debugPrint('Could not persist rich editor setting: $e');
    }
    notifyInternal();
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

  Post? findPost(String postId) {
    for (final list in _postCache.values) {
      for (final p in list) {
        if (p.id == postId) return p;
      }
    }
    return null;
  }

  String? spaceIdForPost(String postId) {
    for (final e in _postCache.entries) {
      for (final p in e.value) {
        if (p.id == postId) return e.key;
      }
    }
    return null;
  }
}
