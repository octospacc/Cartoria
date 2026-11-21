import 'dart:convert';

import 'models.dart';

/// Snapshot of a composer's state, persisted so that text survives
/// accidental navigation and app restarts.
///
/// Per-field, not global: each composer instance (inline for a space,
/// reply for a post, edit for a post, quote for a post) has its own
/// draft, keyed by a stable string. The draft is preserved until either
/// the corresponding post is published (draft cleared) or the user
/// explicitly resets.
class ComposerDraft {
  final String fieldKey;
  final PostKind kind;

  /// Plaintext snapshot of the body. Always populated so legacy drafts
  /// keep working and `bodyFromHtml`-based comparisons remain valid.
  final String body;

  /// Rich-editor state (Quill delta JSON), when the draft was written by
  /// a WYSIWYG composer. Null for drafts from the plaintext editor, or
  /// from a previous version of the app. Loading a null `bodyDelta`
  /// falls back to treating [body] as plain paragraphs.
  final String? bodyDelta;

  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> fileIds;
  final DateTime? postDateTime;
  final bool skipHooks;
  final DateTime savedAt;

  const ComposerDraft({
    required this.fieldKey,
    required this.kind,
    required this.body,
    this.bodyDelta,
    this.url,
    this.title,
    this.description,
    this.thumbnail,
    this.fileIds = const [],
    this.postDateTime,
    this.skipHooks = false,
    required this.savedAt,
  });

  /// True when every field is at its default state. An "empty" rich
  /// delta still counts as empty — a Quill document with no text has a
  /// non-null `bodyDelta` (the minimal `{"ops":[{"insert":"\n"}]}`).
  bool get isEmpty =>
      body.isEmpty &&
      (bodyDelta == null || bodyDelta!.isEmpty || _isMinimalDelta) &&
      (url == null || url!.isEmpty) &&
      (title == null || title!.isEmpty) &&
      (description == null || description!.isEmpty) &&
      thumbnail == null &&
      fileIds.isEmpty &&
      postDateTime == null &&
      !skipHooks &&
      kind == PostKind.note;

  bool get _isMinimalDelta {
    final d = bodyDelta;
    if (d == null || d.isEmpty) return true;
    try {
      final parsed = jsonDecode(d);
      // Quill's empty document is a single operation that inserts a
      // newline. The exact JSON text varies by version (whitespace,
      // optional `attributes: {}`), so parse and inspect rather than
      // comparing strings.
      if (parsed is! List || parsed.length != 1) return false;
      final op = parsed.first;
      if (op is! Map) return false;
      if (op['insert'] != '\n') return false;
      final attrs = op['attributes'];
      if (attrs is Map && attrs.isNotEmpty) return false;
      return true;
    } catch (_) {
      // Malformed delta — treat as not-empty so it's preserved rather
      // than silently discarded.
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'fieldKey': fieldKey,
        'kind': kind.name,
        'body': body,
        if (bodyDelta != null && bodyDelta!.isNotEmpty)
          'bodyDelta': bodyDelta,
        if (url != null && url!.isNotEmpty) 'url': url,
        if (title != null && title!.isNotEmpty) 'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (thumbnail != null && thumbnail!.isNotEmpty)
          'thumbnail': thumbnail,
        if (fileIds.isNotEmpty) 'fileIds': fileIds,
        if (postDateTime != null)
          'postDateTime': postDateTime!.toIso8601String(),
        'skipHooks': skipHooks,
        'savedAt': savedAt.toIso8601String(),
      };

  factory ComposerDraft.fromJson(Map<String, dynamic> j) => ComposerDraft(
        fieldKey: j['fieldKey'] as String,
        kind: PostKind.values.byName((j['kind'] as String?) ?? 'note'),
        body: (j['body'] as String?) ?? '',
        bodyDelta: j['bodyDelta'] as String?,
        url: j['url'] as String?,
        title: j['title'] as String?,
        description: j['description'] as String?,
        thumbnail: j['thumbnail'] as String?,
        fileIds: ((j['fileIds'] as List?) ?? const []).cast<String>(),
        postDateTime: j['postDateTime'] != null
            ? DateTime.tryParse(j['postDateTime'] as String)
            : null,
        skipHooks: (j['skipHooks'] as bool?) ?? false,
        savedAt: DateTime.parse(j['savedAt'] as String),
      );
}