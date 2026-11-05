import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/html_utils.dart';
import '../models.dart';

/// Reads and writes a space's posts as individual `posts/<id>.html`
/// documents (HTML body with a JSON frontmatter block).
///
/// Blockquotes in the body are extracted into [Post.quotedExternals] on
/// load and re-serialised on save, so editing a post's text never touches
/// its quotes. Own-repo quotes travel as the `quotedPostId` frontmatter
/// field and are not represented as HTML.
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
    final rawBody = bodyAfterFrontmatter(content);
    final (cleanBody, externals) = _extractBlockquotes(rawBody);

    final hookState = <String, PostHookState>{};
    final rawHooks = meta['hooks'];
    if (rawHooks is Map) {
      for (final e in rawHooks.entries) {
        try {
          hookState[e.key as String] =
              PostHookState.fromJson((e.value as Map).cast<String, dynamic>());
        } catch (err) {
          debugPrint('Bad hook state ${e.key}: $err');
        }
      }
    }

    return Post(
      id: (meta['id'] as String?) ?? p.basenameWithoutExtension(path),
      parentId: meta['parent'] as String?,
      kind: PostKind.values.byName((meta['kind'] as String?) ?? 'note'),
      body: cleanBody,
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
      quotedPostId: meta['quotedPostId'] as String?,
      quotedExternals: externals,
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
    String? quotedPostId,
    List<QuotedExternal> quotedExternals = const [],
    Map<String, PostHookState> hookState = const {},
  }) async {
    final id = const Uuid().v7();
    final now = createdAt ?? DateTime.now().toUtc();
    final html = _appendBlockquotes(bodyToHtml(plaintextBody), quotedExternals);
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
      if (thumbnail != null && thumbnail.isNotEmpty) 'thumbnail': thumbnail,
      if (quotedPostId != null) 'quotedPostId': quotedPostId,
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
      body: bodyToHtml(plaintextBody),
      url: url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      tags: tags,
      fileIds: fileIds,
      createdAt: now,
      quotedPostId: quotedPostId,
      quotedExternals: quotedExternals,
      hookState: hookState,
    );
  }

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
    final cleanBody = bodyToHtml(plaintextBody);
    final html = _appendBlockquotes(cleanBody, existing.quotedExternals);
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
      if (thumbnail != null && thumbnail.isNotEmpty) 'thumbnail': thumbnail,
      if (existing.quotedPostId != null) 'quotedPostId': existing.quotedPostId,
      if (existing.hookState.isNotEmpty)
        'hooks': existing.hookState.map((k, v) => MapEntry(k, v.toJson())),
    };
    await fs
        .file(p.join(vaultPath, spaceId, 'posts', '${existing.id}.html'))
        .writeAsString(makeDocument(meta, html));
    return Post(
      id: existing.id,
      parentId: existing.parentId,
      kind: kind,
      body: cleanBody,
      url: url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      tags: tags,
      fileIds: fileIds,
      createdAt: existing.createdAt,
      editedAt: now,
      quotedPostId: existing.quotedPostId,
      quotedExternals: existing.quotedExternals,
      hookState: existing.hookState,
    );
  }

  /// Returns the raw on-disk representation of a post: frontmatter block
  /// (`<!--- … --->`) followed by HTML body. Used by the "Show source"
  /// menu entry to display the exact file content.
  Future<String> readSource(String spaceId, String postId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '$postId.html'));
    if (!await f.exists()) {
      throw StateError('Post $postId not found');
    }
    return f.readAsString();
  }

  Future<void> delete(String spaceId, String postId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '$postId.html'));
    if (await f.exists()) await f.delete();
  }

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

  // ── Blockquote helpers ─────────────────────────────────────────────────

  /// Extracts `<blockquote data-author="…" data-uri="…">text</blockquote>`
  /// blocks from [html]. Returns the HTML with those blocks removed, plus
  /// the parsed [QuotedExternal] entries in document order.
  (String, List<QuotedExternal>) _extractBlockquotes(String html) {
    final bq = RegExp(
      r'<blockquote([^>]*)>(.*?)</blockquote>',
      dotAll: true,
      caseSensitive: false,
    );
    final attr = RegExp(r'data-([\w-]+)\s*=\s*"([^"]*)"');
    final quotes = <QuotedExternal>[];
    final stripped = html.replaceAllMapped(bq, (m) {
      final attrs = <String, String>{};
      for (final a in attr.allMatches(m.group(1)!)) {
        attrs[a.group(1)!] = a.group(2)!;
      }
      quotes.add(QuotedExternal(
        author: attrs['author'],
        uri: attrs['uri'],
        text: unescapeHtml(m.group(2)!.trim()),
      ));
      return '';
    });
    return (stripped.trim(), quotes);
  }

  String _appendBlockquotes(String bodyHtml, List<QuotedExternal> quotes) {
    if (quotes.isEmpty) return bodyHtml;
    final buf = StringBuffer(bodyHtml);
    for (final q in quotes) {
      buf.write('\n<blockquote');
      if (q.author != null && q.author!.isNotEmpty) {
        buf.write(' data-author="${escapeHtml(q.author!)}"');
      }
      if (q.uri != null && q.uri!.isNotEmpty) {
        buf.write(' data-uri="${escapeHtml(q.uri!)}"');
      }
      buf.write('>${escapeHtml(q.text)}</blockquote>');
    }
    return buf.toString();
  }
}
