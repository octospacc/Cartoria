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

    final hookState = <String, PostHookState>{};
    final rawHooks = meta['hooks'];
    if (rawHooks is Map) {
      for (final e in rawHooks.entries) {
        try {
          hookState[e.key as String] = PostHookState.fromJson(
              (e.value as Map).cast<String, dynamic>());
        } catch (err) {
          debugPrint('Bad hook state ${e.key}: $err');
        }
      }
    }

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
      hookState: hookState,
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
    DateTime? createdAt,
    Map<String, PostHookState> hookState = const {},
  }) async {
    final id = const Uuid().v7();
    final now = createdAt ?? DateTime.now().toUtc();
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
      if (hookState.isNotEmpty)
        'hooks': hookState.map((k, v) => MapEntry(k, v.toJson())),
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
      hookState: hookState,
    );
  }

  /// Rewrites the HTML document for [existing] with new content, preserving
  /// the original `id`, `created`, `parent`, and `hooks` state. Returns the
  /// new [Post] so the caller can swap its cache entry in place.
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
      if (existing.hookState.isNotEmpty)
        'hooks':
            existing.hookState.map((k, v) => MapEntry(k, v.toJson())),
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
      hookState: existing.hookState,
    );
  }

  Future<void> delete(String spaceId, String postId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '$postId.html'));
    if (await f.exists()) await f.delete();
  }

  /// Merges [updates] into the post's frontmatter `hooks` field and returns
  /// the re-read post. Used by the hook executor to persist each hook's
  /// response without touching the post body or edit timestamp.
  ///
  /// Callers must serialise access to a given post (the facade holds a
  /// per-post lock) so a pending update can't clobber a hook patch.
  Future<Post> patchHookState(
    String spaceId,
    String postId,
    Map<String, PostHookState> updates,
  ) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '$postId.html'));
    if (!await f.exists()) {
      throw StateError('Post $postId not found');
    }
    final content = await f.readAsString();
    final meta = parseFrontmatterMeta(content);
    final body = bodyAfterFrontmatter(content);

    final current = <String, dynamic>{
      for (final e in ((meta['hooks'] as Map?) ?? const {}).entries)
        e.key as String: e.value,
    };
    for (final e in updates.entries) {
      current[e.key] = e.value.toJson();
    }
    meta['hooks'] = current;
    await f.writeAsString(makeDocument(meta, body));
    return _parse(f.path, await f.readAsString());
  }
}