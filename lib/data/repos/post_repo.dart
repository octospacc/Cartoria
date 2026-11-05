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
///
/// File parsing is exposed via the static [parseContent] so archive
/// import/export can decode posts without an instance (no vault path
/// needed to parse a string into a [Post]).
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
        result.add(parseContent(e.path, await e.readAsString()));
      } catch (err) {
        debugPrint('Bad post ${e.path}: $err');
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
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

  Future<void> delete(String spaceId, String postId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '$postId.html'));
    if (await f.exists()) await f.delete();
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
    return parseContent(f.path, await f.readAsString());
  }

  // ── Static parsing ─────────────────────────────────────────────────────

  /// Parses an on-disk post file (frontmatter + HTML body) into a [Post].
  /// Does not touch [fs] or [vaultPath], so it can be called on zip entries
  /// during import without constructing a repository.
  ///
  /// The `path` is used only to derive a fallback id when the frontmatter
  /// lacks an `id` field — malformed / hand-edited files.
  static Post parseContent(String path, String content) {
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

  // ── Import into an existing space ──────────────────────────────────────

  /// Writes an existing in-memory [Post] into [spaceId] on disk, preserving
  /// its id and every metadata field. Used for importing a space zip into
  /// another space; the caller is responsible for skip-if-exists logic.
  ///
  /// [overrideParentId] rewrites the reply target — used when an import
  /// policy skipped the original parent (e.g. dedupe by URL) and the reply
  /// would otherwise dangle.
  Future<Post> importExisting({
    required String spaceId,
    required Post post,
    String? overrideParentId,
  }) async {
    final effectiveParentId = overrideParentId ?? post.parentId;
    final html = _appendBlockquotes(post.body, post.quotedExternals);
    final meta = <String, dynamic>{
      'id': post.id,
      'kind': post.kind.name,
      'created': post.createdAt.toIso8601String(),
      if (effectiveParentId != null) 'parent': effectiveParentId,
      if (post.tags.isNotEmpty) 'tags': post.tags,
      if (post.fileIds.isNotEmpty) 'files': post.fileIds,
      if (post.url != null && post.url!.isNotEmpty) 'url': post.url,
      if (post.title != null && post.title!.isNotEmpty) 'title': post.title,
      if (post.description != null && post.description!.isNotEmpty)
        'description': post.description,
      if (post.thumbnail != null && post.thumbnail!.isNotEmpty)
        'thumbnail': post.thumbnail,
      if (post.quotedPostId != null) 'quotedPostId': post.quotedPostId,
      if (post.editedAt != null) 'edited': post.editedAt!.toIso8601String(),
      if (post.hookState.isNotEmpty)
        'hooks': post.hookState.map((k, v) => MapEntry(k, v.toJson())),
    };
    await fs
        .directory(p.join(vaultPath, spaceId, 'posts'))
        .create(recursive: true);
    final f = fs.file(p.join(vaultPath, spaceId, 'posts', '${post.id}.html'));
    await f.writeAsString(makeDocument(meta, html));
    return parseContent(f.path, await f.readAsString());
  }

  // ── Blockquote helpers (static, no instance state) ─────────────────────

  /// Extracts `<blockquote data-author="…" data-uri="…">text</blockquote>`
  /// blocks from [html]. Returns the HTML with those blocks removed, plus
  /// the parsed [QuotedExternal] entries in document order.
  ///
  /// Static because it touches nothing on the instance — used both by
  /// [parseContent] (static context) and by the instance `update`/`create`
  /// paths through [_appendBlockquotes].
  static (String, List<QuotedExternal>) _extractBlockquotes(String html) {
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

  /// Appends semantic `<blockquote>` elements for [quotes] to [bodyHtml].
  /// Static for the same reason as [_extractBlockquotes].
  static String _appendBlockquotes(
    String bodyHtml,
    List<QuotedExternal> quotes,
  ) {
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
