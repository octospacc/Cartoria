import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/html_utils.dart';
import '../models.dart';

/// Reads and writes a space's entries as individual `entries/<id>.html`
/// documents (HTML body with a JSON frontmatter block).
///
/// "Entry" is the on-disk collection name — one entry per post, note,
/// bookmark, or reply. The type is still [Post] because that's the
/// accurate technical umbrella (a bookmark is a post, a reply is a post);
/// the folder name just shouldn't say "posts" when the UI never does.
///
/// Legacy spaces may still store entries under `posts/`. Every method
/// resolves the actual directory at call time via [_entriesDir], so a
/// vault whose startup migration failed still loads and writes correctly.
/// New spaces always get `entries/`.
///
/// Blockquotes in the body are extracted into [Post.quotedExternals] on
/// load and re-serialised on save, so editing a post's text never touches
/// its quotes. Own-repo quotes travel as the `quotedPostId` frontmatter
/// field and are not represented as HTML.
class PostRepository {
  final FileSystem fs;
  final String vaultPath;

  const PostRepository({required this.fs, required this.vaultPath});

  // ── Directory resolution (current + legacy) ────────────────────────────

  /// Returns the on-disk directory holding this space's entries.
  ///
  /// Prefers `entries/`. Falls back to `posts/` for spaces whose startup
  /// migration didn't run (fresh install before migration, migration
  /// error, or a vault authored by an older version of the app).
  ///
  /// When [create] is true and neither directory exists, creates
  /// `entries/` — the current scheme. Never creates `posts/`.
  Future<Directory> _entriesDir(String spaceId, {bool create = false}) async {
    final entriesDir = fs.directory(p.join(vaultPath, spaceId, 'entries'));
    if (await entriesDir.exists()) return entriesDir;

    final legacyDir = fs.directory(p.join(vaultPath, spaceId, 'posts'));
    if (await legacyDir.exists()) return legacyDir;

    if (create) await entriesDir.create(recursive: true);
    return entriesDir;
  }

  // ── Public API ─────────────────────────────────────────────────────────

  Future<List<Post>> list(String spaceId) async {
    final dir = await _entriesDir(spaceId);
    if (!await dir.exists()) return const [];

    final result = <Post>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || !e.path.endsWith('.html')) continue;
      try {
        result.add(parseContent(e.path, await e.readAsString()));
      } catch (err) {
        debugPrint('Bad entry ${e.path}: $err');
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
    // Normalise: caller may pass a local DateTime (from the picker), which
    // must be stored as UTC to compare correctly against DateTime.now().toUtc()
    // and to render back through .toLocal().
    final now = (createdAt ?? DateTime.now()).toUtc();
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
    final dir = await _entriesDir(spaceId, create: true);
    await fs
        .file(p.join(dir.path, '$id.html'))
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
    final dir = await _entriesDir(spaceId);
    await fs
        .file(p.join(dir.path, '${existing.id}.html'))
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
    final dir = await _entriesDir(spaceId);
    final f = fs.file(p.join(dir.path, '$postId.html'));
    if (await f.exists()) await f.delete();
  }

  /// Deletes multiple entries in a single pass. One directory listing,
  /// N deletes. Skips missing files silently so a double-delete or a
  /// manually-removed file doesn't abort the batch.
  Future<void> deleteMultiple(String spaceId, Set<String> postIds) async {
    if (postIds.isEmpty) return;
    final dir = await _entriesDir(spaceId);
    for (final id in postIds) {
      try {
        final f = fs.file(p.join(dir.path, '$id.html'));
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Failed to delete entry $id: $e');
      }
    }
  }

  /// Returns the raw on-disk representation of an entry: frontmatter block
  /// (`<!--- … --->`) followed by HTML body. Used by the "Show source" menu
  /// entry to display the exact file content.
  Future<String> readSource(String spaceId, String postId) async {
    final dir = await _entriesDir(spaceId);
    final f = fs.file(p.join(dir.path, '$postId.html'));
    if (!await f.exists()) {
      throw StateError('Entry $postId not found');
    }
    return f.readAsString();
  }

  /// Returns the on-disk path where [postId]'s source lives, or null if the
  /// file isn't present under either `entries/` or the legacy `posts/`
  /// directory. Used by the source dialog to display (and let the user
  /// copy) the exact location rather than guessing it.
  Future<String?> filePath(String spaceId, String postId) async {
    final dir = await _entriesDir(spaceId);
    final f = fs.file(p.join(dir.path, '$postId.html'));
    if (await f.exists()) return f.path;
    return null;
  }

  Future<Post> patchHookState(
    String spaceId,
    String postId,
    Map<String, PostHookState> updates,
  ) async {
    final dir = await _entriesDir(spaceId);
    final f = fs.file(p.join(dir.path, '$postId.html'));
    if (!await f.exists()) {
      throw StateError('Entry $postId not found');
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

  /// Parses an on-disk entry file (frontmatter + HTML body) into a [Post].
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

  /// Parses a single post from an in-memory string in the same format as
  /// an on-disk `entries/<id>.html` file. Validates the frontmatter and
  /// synthesises an id if the source lacks one, so pasting the body of a
  /// post with no `id` field still works.
  ///
  /// Throws [FormatException] with a user-facing message on any of:
  /// missing frontmatter, malformed JSON, missing/invalid `created`,
  /// unknown `kind`.
  static Post parseInlinePost(String source) {
    if (!source.trimLeft().startsWith('<!---')) {
      throw const FormatException(
        'Not a Cartoria post: missing <!--- frontmatter block.',
      );
    }

    final Map<String, dynamic> meta;
    try {
      meta = parseFrontmatterMeta(source);
    } catch (e) {
      throw FormatException('Could not parse frontmatter: $e');
    }

    final created = meta['created'];
    if (created is! String) {
      throw const FormatException(
        'Post is missing a "created" timestamp.',
      );
    }
    try {
      DateTime.parse(created);
    } catch (_) {
      throw const FormatException(
        'Post has an invalid "created" timestamp. Expected ISO 8601.',
      );
    }

    final kindStr = (meta['kind'] as String?) ?? 'note';
    if (kindStr != 'note' && kindStr != 'bookmark') {
      throw FormatException(
        'Unknown post kind "$kindStr" (expected "note" or "bookmark").',
      );
    }

    final withId = <String, dynamic>{
      ...meta,
      'id': (meta['id'] as String?) ?? const Uuid().v7(),
    };
    return parseContent(
      'inline.html',
      makeDocument(withId, bodyAfterFrontmatter(source)),
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
    final dir = await _entriesDir(spaceId, create: true);
    final f = fs.file(p.join(dir.path, '${post.id}.html'));
    await f.writeAsString(makeDocument(meta, html));
    return parseContent(f.path, await f.readAsString());
  }

  // ── Blockquote helpers (static, no instance state) ─────────────────────

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
      // Only semantic quotes carry `data-author` or `data-uri` — those
      // are what the Bluesky importer emits, and what the app surfaces
      // as an inner quote card. A plain markdown blockquote (just
      // `<blockquote>text</blockquote>`, no attributes) is body content
      // and must stay in place so PostBodyText can render it as a
      // standard styled quote.
      if (!attrs.containsKey('author') && !attrs.containsKey('uri')) {
        return m.group(0)!; // leave in body
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
