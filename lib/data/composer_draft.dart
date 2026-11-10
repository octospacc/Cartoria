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
  final String body;
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
    this.url,
    this.title,
    this.description,
    this.thumbnail,
    this.fileIds = const [],
    this.postDateTime,
    this.skipHooks = false,
    required this.savedAt,
  });

  /// True when every field is at its default state. Empty drafts are
  /// deleted rather than saved, so the store doesn't accumulate noise.
  bool get isEmpty =>
      body.isEmpty &&
      (url == null || url!.isEmpty) &&
      (title == null || title!.isEmpty) &&
      (description == null || description!.isEmpty) &&
      thumbnail == null &&
      fileIds.isEmpty &&
      postDateTime == null &&
      !skipHooks &&
      kind == PostKind.note;

  Map<String, dynamic> toJson() => {
        'fieldKey': fieldKey,
        'kind': kind.name,
        'body': body,
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