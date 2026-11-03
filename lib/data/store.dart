import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:opengraph/opengraph.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../platform/fs.dart';
import '../util/html_utils.dart';
import 'models.dart';

/// Result of fetching Open Graph metadata for a URL.
class LinkMetadata {
  final String? title;
  final String? description;
  final String? image;

  const LinkMetadata({this.title, this.description, this.image});
}

class SpaceStats {
  final int totalPosts;
  final int notes;        // all notes, including replies
  final int bookmarks;    // all bookmarks, including replies
  final int replies;      // any post with a parent (regardless of kind)
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

class VaultStore extends ChangeNotifier {
  late final FileSystem fs;
  late final String vaultPath;

  final List<Space> _spaces = [];
  final Map<String, List<Post>> _posts = {};
  final Map<String, List<DriveFile>> _files = {};
  final Map<String, Uint8List> _imageCache = {};

  List<Space> get spaces => List.unmodifiable(_spaces);

  List<Post> postsForSpace(String spaceId) =>
      List.unmodifiable(_posts[spaceId] ?? const <Post>[]);

  List<DriveFile> filesForSpace(String spaceId) =>
      List.unmodifiable(_files[spaceId] ?? const <DriveFile>[]);

  Space? spaceById(String id) {
    for (final s in _spaces) {
      if (s.id == id) return s;
    }
    return null;
  }

  DriveFile? fileById(String spaceId, String fileId) {
    for (final f in _files[spaceId] ?? const <DriveFile>[]) {
      if (f.id == fileId) return f;
    }
    return null;
  }

  Future<void> init() async {
    fs = createFs();
    if (kIsWeb) {
      vaultPath = '/vault';
      // Route through a CORS proxy so Open Graph fetches work from browsers.
      // Swap for your own proxy in production.
      OpengraphFetch.proxyUrl = 'https://corsproxy.io/?url={url}';
    } else {
      final docs = await getApplicationDocumentsDirectory();
      vaultPath = p.join(docs.path, 'vault');
    }
    await fs.directory(vaultPath).create(recursive: true);
    await reload();
  }

  Future<void> reload() async {
    _spaces.clear();
    _posts.clear();
    _files.clear();

    final root = fs.directory(vaultPath);
    if (!await root.exists()) {
      notifyListeners();
      return;
    }

    final dirs = <Directory>[];
    await for (final e in root.list(followLinks: false)) {
      if (e is Directory) dirs.add(e);
    }

    for (final dir in dirs) {
      final id = p.basename(dir.path);
      try {
        final space = await _readSpace(id);
        if (space == null) continue;
        _spaces.add(space);
        _posts[id] = await _readPosts(id);
        _files[id] = await _readFiles(id);
      } catch (e) {
        debugPrint('Failed to load space $id: $e');
      }
    }

    _spaces.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<Space?> _readSpace(String id) async {
    final f = fs.file(p.join(vaultPath, id, 'space.html'));
    if (!await f.exists()) return null;
    final content = await f.readAsString();
    final meta = parseFrontmatterMeta(content);
    return Space(
      id: (meta['id'] as String?) ?? id,
      name: (meta['name'] as String?) ?? id,
      icon: (meta['icon'] as String?) ?? '📓',
      createdAt: DateTime.parse(meta['created'] as String),
    );
  }

  Future<List<Post>> _readPosts(String spaceId) async {
    final dir = fs.directory(p.join(vaultPath, spaceId, 'posts'));
    if (!await dir.exists()) return const [];
    final result = <Post>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || !e.path.endsWith('.html')) continue;
      try {
        result.add(_parsePost(e.path, await e.readAsString()));
      } catch (err) {
        debugPrint('Bad post ${e.path}: $err');
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  Post _parsePost(String path, String content) {
    final meta = parseFrontmatterMeta(content);
    return Post(
      id: (meta['id'] as String?) ?? p.basenameWithoutExtension(path),
      parentId: meta['parent'] as String?,
      kind: PostKind.values.byName((meta['kind'] as String?) ?? 'note'),
      body: bodyAfterFrontmatter(content),
      url: meta['url'] as String?,
      title: meta['title'] as String?,
      description: meta['description'] as String?,
      thumbnail: meta['thumbnail'] as String?,
      tags: ((meta['tags'] as List?) ?? const []).cast<String>(),
      fileIds: ((meta['files'] as List?) ?? const []).cast<String>(),
      createdAt: DateTime.parse(meta['created'] as String),
      editedAt: meta['edited'] != null
          ? DateTime.parse(meta['edited'] as String)
          : null,
    );
  }

  Future<List<DriveFile>> _readFiles(String spaceId) async {
    final meta = await _readDriveMeta(spaceId);
    final result = <DriveFile>[];
    for (final entry in meta.entries) {
      final id = entry.key;
      final m = entry.value;
      final file = fs.file(p.join(vaultPath, spaceId, 'drive', id));
      if (!await file.exists()) continue;
      try {
        result.add(DriveFile(
          id: id,
          name: (m['name'] as String?) ?? id,
          sizeBytes: (await file.stat()).size,
          createdAt: DateTime.parse((m['created'] as String)),
        ));
      } catch (err) {
        debugPrint('Bad drive file $id: $err');
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _readDriveMeta(
      String spaceId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'drive_meta.json'));
    if (!await f.exists()) return {};
    final raw = jsonDecode(await f.readAsString()) as Map;
    return raw.map((k, v) =>
        MapEntry(k as String, (v as Map).cast<String, dynamic>()));
  }

  Future<void> _writeDriveMeta(
      String spaceId, Map<String, Map<String, dynamic>> meta) async {
    await fs
        .file(p.join(vaultPath, spaceId, 'drive_meta.json'))
        .writeAsString(jsonEncode(meta));
  }

  Future<Space> createSpace({required String name, String icon = '📓'}) async {
    final id = const Uuid().v7();
    final now = DateTime.now().toUtc();
    final dir = p.join(vaultPath, id);
    await fs.directory(p.join(dir, 'posts')).create(recursive: true);
    await fs.directory(p.join(dir, 'drive')).create(recursive: true);
    await _writeDriveMeta(id, {});
    final meta = <String, dynamic>{
      'id': id,
      'name': name,
      'icon': icon,
      'created': now.toIso8601String(),
    };
    await fs
        .file(p.join(dir, 'space.html'))
        .writeAsString(makeDocument(meta, '<h1>${escapeHtml(name)}</h1>'));
    final space = Space(id: id, name: name, icon: icon, createdAt: now);
    _spaces.insert(0, space);
    _posts[id] = [];
    _files[id] = [];
    notifyListeners();
    return space;
  }

  Future<void> deleteSpace(String spaceId) async {
    final dir = fs.directory(p.join(vaultPath, spaceId));
    if (await dir.exists()) await dir.delete(recursive: true);
    _spaces.removeWhere((s) => s.id == spaceId);
    _posts.remove(spaceId);
    _files.remove(spaceId);
    _imageCache.removeWhere((k, _) => k.startsWith('$spaceId:'));
    notifyListeners();
  }

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
    final id = const Uuid().v7();
    final now = DateTime.now().toUtc();
    final html = bodyToHtml(plaintextBody);
    final meta = <String, dynamic>{
      'id': id,
      'kind': kind.name,
      'created': now.toIso8601String(),
      if (parentId != null) 'parent': parentId,
      if (tags.isNotEmpty) 'tags': tags,
      if (fileIds.isNotEmpty) 'files': fileIds,
      if (url != null && url.isNotEmpty) 'url': url,
      if (title != null && title.isNotEmpty) 'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (thumbnail != null && thumbnail.isNotEmpty)
        'thumbnail': thumbnail,
    };
    await fs
        .directory(p.join(vaultPath, spaceId, 'posts'))
        .create(recursive: true);
    await fs
        .file(p.join(vaultPath, spaceId, 'posts', '$id.html'))
        .writeAsString(makeDocument(meta, html));
    final post = Post(
      id: id,
      parentId: parentId,
      kind: kind,
      body: html,
      url: url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      tags: tags,
      fileIds: fileIds,
      createdAt: now,
    );
    _posts.putIfAbsent(spaceId, () => []).add(post);
    notifyListeners();
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
    final list = _posts[spaceId];
    if (list == null) return;
    final idx = list.indexWhere((x) => x.id == postId);
    if (idx < 0) return;
    final existing = list[idx];
    final html = bodyToHtml(plaintextBody);
    final now = DateTime.now().toUtc();
    final meta = <String, dynamic>{
      'id': postId,
      'kind': kind.name,
      'created': existing.createdAt.toIso8601String(),
      'edited': now.toIso8601String(),
      if (existing.parentId != null) 'parent': existing.parentId,
      if (tags.isNotEmpty) 'tags': tags,
      if (fileIds.isNotEmpty) 'files': fileIds,
      if (url != null && url.isNotEmpty) 'url': url,
      if (title != null && title.isNotEmpty) 'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (thumbnail != null && thumbnail.isNotEmpty)
        'thumbnail': thumbnail,
    };
    await fs
        .file(p.join(vaultPath, spaceId, 'posts', '$postId.html'))
        .writeAsString(makeDocument(meta, html));
    list[idx] = Post(
      id: postId,
      parentId: existing.parentId,
      kind: kind,
      body: html,
      url: url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      tags: tags,
      fileIds: fileIds,
      createdAt: existing.createdAt,
      editedAt: now,
    );
    notifyListeners();
  }

  Future<void> deletePost(String spaceId, String postId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '$postId.html'));
    if (await f.exists()) await f.delete();
    _posts[spaceId]?.removeWhere((x) => x.id == postId);
    notifyListeners();
  }

  Future<DriveFile> addFileFromBytes({
    required String spaceId,
    required Uint8List bytes,
    required String name,
  }) async {
    final id = const Uuid().v7();
    final now = DateTime.now().toUtc();
    await fs
        .directory(p.join(vaultPath, spaceId, 'drive'))
        .create(recursive: true);
    await fs.file(p.join(vaultPath, spaceId, 'drive', id)).writeAsBytes(bytes);
    final meta = await _readDriveMeta(spaceId);
    meta[id] = {'name': name, 'created': now.toIso8601String()};
    await _writeDriveMeta(spaceId, meta);
    final file = DriveFile(
      id: id,
      name: name,
      sizeBytes: bytes.length,
      createdAt: now,
    );
    _files.putIfAbsent(spaceId, () => []).add(file);
    notifyListeners();
    return file;
  }

  Future<Uint8List> readFileBytes(String spaceId, String fileId) async {
    return fs.file(p.join(vaultPath, spaceId, 'drive', fileId)).readAsBytes();
  }

  Future<Uint8List> readImageBytes(String spaceId, String fileId) async {
    final key = '$spaceId:$fileId';
    final cached = _imageCache[key];
    if (cached != null) return cached;
    final bytes = await readFileBytes(spaceId, fileId);
    _imageCache[key] = bytes;
    return bytes;
  }

  Future<void> deleteFile(String spaceId, String fileId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'drive', fileId));
    if (await f.exists()) await f.delete();
    final meta = await _readDriveMeta(spaceId);
    meta.remove(fileId);
    await _writeDriveMeta(spaceId, meta);
    _files[spaceId]?.removeWhere((x) => x.id == fileId);
    _imageCache.remove('$spaceId:$fileId');
    notifyListeners();
  }

  Future<Uint8List> exportSpaceZip(String spaceId) async {
    final archive = Archive();
    final dirPath = p.join(vaultPath, spaceId);
    final files = await _walkFiles(fs.directory(dirPath));
    for (final f in files) {
      try {
        final rel = p.relative(f.path, from: dirPath);
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile('$spaceId/$rel', bytes.length, bytes));
      } catch (e) {
        debugPrint('Skipping unreadable file ${f.path}: $e');
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  Future<List<File>> _walkFiles(Directory dir) async {
    final result = <File>[];
    try {
      if (!await dir.exists()) return result;
      await for (final e in dir.list(followLinks: false)) {
        if (e is File) {
          result.add(e);
        } else if (e is Directory) {
          result.addAll(await _walkFiles(e));
        }
      }
    } catch (e) {
      debugPrint('Failed to walk ${dir.path}: $e');
    }
    return result;
  }

  Future<String> importSpaceZip(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? spaceFile;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == 'space.html' || f.name.endsWith('/space.html')) {
        if (spaceFile == null || f.name.length < spaceFile.name.length) {
          spaceFile = f;
        }
      }
    }
    if (spaceFile == null) {
      throw const FormatException('Zip does not contain space.html');
    }

    final content = utf8.decode(spaceFile.content as List<int>);
    final meta = parseFrontmatterMeta(content);
    var newId = (meta['id'] as String?) ?? const Uuid().v7();
    final conflict = await fs.directory(p.join(vaultPath, newId)).exists();
    if (conflict) newId = const Uuid().v7();

    final spaceDir = p.dirname(spaceFile.name);
    final prefix = (spaceDir.isEmpty || spaceDir == '.') ? '' : '$spaceDir/';
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith(prefix)) continue;
      final rel = f.name.substring(prefix.length);
      if (rel.isEmpty) continue;
      final dest = p.join(vaultPath, newId, rel);
      await fs.directory(p.dirname(dest)).create(recursive: true);
      await fs
          .file(dest)
          .writeAsBytes(Uint8List.fromList(f.content as List<int>));
    }

    if (conflict) {
      final updated = {...meta, 'id': newId};
      final body = bodyAfterFrontmatter(content);
      await fs
          .file(p.join(vaultPath, newId, 'space.html'))
          .writeAsString(makeDocument(updated, body));
    }

    await reload();
    return newId;
  }

  /// Fetches Open Graph metadata for [url].
  /// Returns `null` on failure or timeout — the caller should save the
  /// bookmark anyway, just without metadata.
  Future<LinkMetadata?> fetchLinkMetadata(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      final data = await opengraph_fetch(
        url,
        timeout: const Duration(seconds: 8),
      );
      if (data == null) return null;
      String? clean(String s) {
        final t = s.trim();
        return t.isEmpty ? null : t;
      }
      return LinkMetadata(
        title: clean(data.title),
        description: clean(data.description),
        image: clean(data.image),
      );
    } catch (e) {
      debugPrint('Metadata fetch failed for $url: $e');
      return null;
    }
  }

  /// Computes counts for [spaceId], plus the total on-disk size of the
  /// space directory (posts + drive blobs + metadata files).
  ///
  /// Walks the filesystem for the storage figure — call this on demand
  /// (e.g. when opening a stats dialog), not on every rebuild.
  Future<SpaceStats> computeStats(String spaceId) async {
    final posts = _posts[spaceId] ?? const <Post>[];
    final files = _files[spaceId] ?? const <DriveFile>[];

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
      final dir = fs.directory(p.join(vaultPath, spaceId));
      final allFiles = await _walkFiles(dir);
      for (final f in allFiles) {
        try {
          storageBytes += (await f.stat()).size;
        } catch (_) {}
      }
    } catch (_) {}

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