import '../util/html_utils.dart';

enum PostKind { note, bookmark }

class Space {
  final String id;
  final String name;
  final String icon;
  final DateTime createdAt;

  const Space({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
  });
}

/// A quote of a post from another account (not in this vault).
///
/// Deserialized from `<blockquote data-author="…" data-uri="…">text</blockquote>`
/// in the post body. [uri] is an `at://` URI that the app can translate to a
/// bsky.app URL; [author] is a handle if available, else the DID.
class QuotedExternal {
  final String? author;
  final String? uri;
  final String text;

  const QuotedExternal({this.author, this.uri, required this.text});
}

class PostHookState {
  final DateTime lastFiredAt;
  final int? lastStatus;
  final String? lastBody;
  final Map<String, String> lastHeaders;
  final String? lastError;

  const PostHookState({
    required this.lastFiredAt,
    this.lastStatus,
    this.lastBody,
    this.lastHeaders = const {},
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'lastFiredAt': lastFiredAt.toIso8601String(),
        if (lastStatus != null) 'lastStatus': lastStatus,
        if (lastBody != null) 'lastBody': lastBody,
        if (lastHeaders.isNotEmpty) 'lastHeaders': lastHeaders,
        if (lastError != null) 'lastError': lastError,
      };

  factory PostHookState.fromJson(Map<String, dynamic> j) => PostHookState(
        lastFiredAt: DateTime.parse(j['lastFiredAt'] as String),
        lastStatus: j['lastStatus'] as int?,
        lastBody: j['lastBody'] as String?,
        lastHeaders: ((j['lastHeaders'] as Map?) ?? const {})
            .cast<String, String>(),
        lastError: j['lastError'] as String?,
      );
}

class Post {
  final String id;
  final String? parentId;
  final PostKind kind;

  /// HTML body — contains only the post's own text (paragraphs, `<br>`).
  /// External quotes are stored separately in [quotedExternals] and are
  /// re-serialised into the body on save.
  final String body;

  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> tags;
  final List<String> fileIds;
  final DateTime createdAt;
  final DateTime? editedAt;

  /// Reference to a post in the same vault that this post quotes. Set for
  /// own-repo quotes; null otherwise.
  final String? quotedPostId;

  /// Quotes of other accounts' posts. Rendered as inner cards, tapping
  /// opens the original on bsky.app.
  final List<QuotedExternal> quotedExternals;

  final Map<String, PostHookState> hookState;

  String? _plaintextCache;
  String? _domainCache;
  String? _formattedCache;
  DateTime? _formattedForDay;
  String? _editedCache;
  DateTime? _editedForDay;

  Post({
    required this.id,
    this.parentId,
    required this.kind,
    required this.body,
    this.url,
    this.title,
    this.description,
    this.thumbnail,
    this.tags = const [],
    this.fileIds = const [],
    required this.createdAt,
    this.editedAt,
    this.quotedPostId,
    this.quotedExternals = const [],
    this.hookState = const {},
  });

  String get plaintext => _plaintextCache ??= bodyFromHtml(body);

  String get domain {
    final u = url;
    if (u == null || u.isEmpty) return '';
    final cached = _domainCache;
    if (cached != null) return cached;
    String d;
    try {
      final uri = Uri.parse(u);
      d = uri.host.isNotEmpty ? uri.host : u;
    } catch (_) {
      d = u;
    }
    return _domainCache = d;
  }

  String get formattedCreatedAt {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_formattedCache == null || _formattedForDay != today) {
      _formattedForDay = today;
      _formattedCache = _format(createdAt, now);
    }
    return _formattedCache!;
  }

  String? get formattedEditedAt {
    final edited = editedAt;
    if (edited == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_editedCache == null || _editedForDay != today) {
      _editedForDay = today;
      _editedCache = _format(edited, now);
    }
    return _editedCache;
  }

  static String _format(DateTime t, DateTime now) {
    final local = t.toLocal();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hh:$mm';
    final ymd = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    return '$ymd $hh:$mm';
  }

  Post withHookState(Map<String, PostHookState> newState) => Post(
        id: id,
        parentId: parentId,
        kind: kind,
        body: body,
        url: url,
        title: title,
        description: description,
        thumbnail: thumbnail,
        tags: tags,
        fileIds: fileIds,
        createdAt: createdAt,
        editedAt: editedAt,
        quotedPostId: quotedPostId,
        quotedExternals: quotedExternals,
        hookState: newState,
      );
}

class DriveFile {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;

  const DriveFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
  });
}