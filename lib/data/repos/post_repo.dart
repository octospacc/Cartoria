import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/html_utils.dart';
import '../models.dart';

/// Reads and writes a space's posts as individual `posts/<id>.html`
/// documents (HTML body with a JSON frontmatter block).
///
/// Stateless w.r.t. caching: every method hits the filesystem. The
/// [VaultStore] facade owns the in-memory cache and notifies listeners.
class PostRepository {
  final FileSystem fs;
  final String vaultPath;

  const PostRepository({required this.fs, required this.vaultPath});

  Future<List<Post>> list(String spaceId) async {
    final dir = fs.directory(p.join(vaultPath, spaceId, 'posts'));
    if (!await dir.exists()) return const [];

    final result = <Post>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || !e.path.endsWith('.html')) continue;
      try {
        result.add(_parse(e.path, await e.readAsString()));
      } catch (err) {
        debugPrint('Bad post ${e.path}: $err');
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  Post _parse(String path, String content) {
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

  Future<Post> create({
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
    DateTime? createdAt,               // ← new
  }) async {
    final id = const Uuid().v7();
    final now = createdAt ?? DateTime.now().toUtc();   // ← was: DateTime.now().toUtc()
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
    return Post(
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
  }

  /// Rewrites the HTML document for [existing] with new content, preserving
  /// the original `id`, `created`, and `parent` fields. Returns the new
  /// [Post] so the caller can swap its cache entry in place.
  Future<Post> update({
    required String spaceId,
    required Post existing,
    required PostKind kind,
    required String plaintextBody,
    String? url,
    String? title,
    String? description,
    String? thumbnail,
    List<String> tags = const [],
    List<String> fileIds = const [],
  }) async {
    final html = bodyToHtml(plaintextBody);
    final now = DateTime.now().toUtc();
    final meta = <String, dynamic>{
      'id': existing.id,
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
        .file(p.join(vaultPath, spaceId, 'posts', '${existing.id}.html'))
        .writeAsString(makeDocument(meta, html));
    return Post(
      id: existing.id,
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
  }

  Future<void> delete(String spaceId, String postId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '$postId.html'));
    if (await f.exists()) await f.delete();
  }
}