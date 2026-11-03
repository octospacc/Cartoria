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

class Post {
  final String id;
  final String? parentId;
  final PostKind kind;
  final String body;
  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> tags;
  final List<String> fileIds;
  final DateTime createdAt;
  final DateTime? editedAt;

  String? _plaintextCache;
  String? _domainCache;
  String? _formattedCache;
  DateTime? _formattedForDay;

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
  });

  /// Plaintext rendering of [body]. Memoised.
  String get plaintext => _plaintextCache ??= bodyFromHtml(body);

  /// Host of [url] (or the raw URL if parsing fails). Memoised.
  ///
  /// Used by [PostCard] and [LinkPreviewCard] on every build; without the
  /// cache, a 5,000-card fast scroll re-parses the same URL thousands of
  /// times a second.
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

  /// `HH:MM` for today, `YYYY-MM-DD HH:MM` otherwise. Memoised, and
  /// invalidated once per day so the "today" check stays honest.
  String get formattedCreatedAt {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_formattedCache == null || _formattedForDay != today) {
      _formattedForDay = today;
      _formattedCache = _format(createdAt, now);
    }
    return _formattedCache!;
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