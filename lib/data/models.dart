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
  final String body; // HTML
  final String? url;
  final String? title;
  final String? description;   // ← new
  final String? thumbnail;     // ← new (URL string)
  final List<String> tags;
  final List<String> fileIds;
  final DateTime createdAt;
  final DateTime? editedAt;

  const Post({
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