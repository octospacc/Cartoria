import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../util/mime.dart';
import '../platform/fs.dart';
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

export 'repos/bookmarks_importer.dart' show BookmarkImportResult;
export 'services/link_metadata.dart' show LinkMetadata;
export 'services/space_stats.dart' show SpaceStats;

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

  final http.Client _httpClient = http.Client();

  final List<Space> _spaceCache = [];
  final Map<String, List<Post>> _postCache = {};
  final Map<String, List<DriveFile>> _fileCache = {};
  final Map<String, Map<String, DriveFile>> _fileIndex = {};
  final Map<String, Uint8List> _imageCache = {};

  /// Per-post serialisation: hooks patch the post file in the background
  /// while a user may be editing it. Both `updatePost` and `_runHooks`
  /// acquire the same lock so they can't interleave a read and a write.
  final Map<String, Future<void>> _postLocks = {};

  /// Per-post serialisation of hook batches: if the user edits rapidly, the
  /// second batch waits for the first to finish rather than racing.
  final Map<String, Future<void>> _hookChains = {};

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
    _link = LinkMetadataService(
      proxyUrl: kIsWeb ? 'https://corsproxy.io/?url={url}' : null,
    );

    await _hooks.load();
    await reload();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Future<void> reload() async {
    _spaceCache.clear();
    _postCache.clear();
    _fileCache.clear();
    _fileIndex.clear();

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
    notifyListeners();
  }

  // ── Spaces ─────────────────────────────────────────────────────────────

  Future<Space> createSpace({required String name, String icon = '📓'}) async {
    final space = await _spaces.create(name: name, icon: icon);
    _spaceCache.insert(0, space);
    _postCache[space.id] = [];
    _fileCache[space.id] = [];
    _fileIndex[space.id] = {};
    notifyListeners();
    return space;
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
    notifyListeners();
  }

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
    _fileCache.putIfAbsent(spaceId, () => []).add(file);
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

    final priorStates = post.hookState;
    final results = <String, PostHookState>{};
    for (final hook in active) {
      results[hook.key] = await _executor.execute(
        hook: hook,
        post: post,
        original: originalSnapshot,
        space: space,
        trigger: trigger,
        priorStates: priorStates,
        files: files,
        resolveFile: resolveFile,
      );
    }
    if (results.isEmpty) return;

    await _withPostLock(postId, () async {
      final patched = await _posts.patchHookState(space.id, postId, results);
      final idx = _postCache[space.id]?.indexWhere((x) => x.id == postId) ?? -1;
      if (idx >= 0) _postCache[space.id]![idx] = patched;
      notifyListeners();
    });
  }
}
