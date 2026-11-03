import '../data/models.dart';

enum HookTrigger { create, edit }

/// One field in a multipart/form-data hook request.
///
/// Exactly one of [template] or [fileIndex] must be non-null:
///   - text part: [template] is rendered with [TemplateEscape.raw] and sent
///     as a form field of the given [name];
///   - file part: bytes are read from `post.fileIds[fileIndex]` and sent
///     under [name] as a file upload, with `Content-Type` inferred from
///     the file's name and `filename` either the vault name or [filename].
class HookMultipartPart {
  final String name;
  final String? template;
  final int? fileIndex;
  final String? filename;

  const HookMultipartPart({
    required this.name,
    this.template,
    this.fileIndex,
    this.filename,
  }) : assert(
          (template == null) != (fileIndex == null),
          'Exactly one of template or fileIndex must be set',
        );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (template != null) 'template': template,
        if (fileIndex != null) 'fileIndex': fileIndex,
        if (filename != null) 'filename': filename,
      };

  factory HookMultipartPart.fromJson(Map<String, dynamic> j) =>
      HookMultipartPart(
        name: j['name'] as String,
        template: j['template'] as String?,
        fileIndex: j['fileIndex'] as int?,
        filename: j['filename'] as String?,
      );
}

class Hook {
  final String id;
  final String key;
  final String name;
  final bool enabled;
  final Set<String> spaceIds;
  final Set<HookTrigger> triggers;
  final Set<PostKind> postKinds;
  final Set<String> tagFilters;
  final String method;
  final String urlTemplate;
  final Map<String, String> headers;
  final String? bodyTemplate;
  final int timeoutSeconds;

  /// When non-empty, the request is sent as multipart/form-data and
  /// [bodyTemplate] is ignored. Each part is either a rendered text field
  /// or a file uploaded from the post's drive attachments.
  final List<HookMultipartPart> multipartParts;

  const Hook({
    required this.id,
    required this.key,
    required this.name,
    this.enabled = true,
    this.spaceIds = const {},
    this.triggers = const {HookTrigger.create, HookTrigger.edit},
    this.postKinds = const {},
    this.tagFilters = const {},
    this.method = 'POST',
    required this.urlTemplate,
    this.headers = const {},
    this.bodyTemplate,
    this.timeoutSeconds = 15,
    this.multipartParts = const [],
  });

  Hook withEnabled(bool value) => Hook(
        id: id,
        key: key,
        name: name,
        enabled: value,
        spaceIds: spaceIds,
        triggers: triggers,
        postKinds: postKinds,
        tagFilters: tagFilters,
        method: method,
        urlTemplate: urlTemplate,
        headers: headers,
        bodyTemplate: bodyTemplate,
        timeoutSeconds: timeoutSeconds,
        multipartParts: multipartParts,
      );

  bool matches({
    required String spaceId,
    required HookTrigger trigger,
    required PostKind postKind,
    required Set<String> postTags,
  }) {
    if (!enabled) return false;
    if (!triggers.contains(trigger)) return false;
    if (spaceIds.isNotEmpty && !spaceIds.contains(spaceId)) return false;
    if (postKinds.isNotEmpty && !postKinds.contains(postKind)) return false;
    if (tagFilters.isNotEmpty &&
        !tagFilters.any((t) => postTags.contains(t))) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'name': name,
        'enabled': enabled,
        'spaceIds': spaceIds.toList(),
        'triggers': triggers.map((t) => t.name).toList(),
        'postKinds': postKinds.map((k) => k.name).toList(),
        'tagFilters': tagFilters.toList(),
        'method': method,
        'urlTemplate': urlTemplate,
        'headers': headers,
        'bodyTemplate': bodyTemplate,
        'timeoutSeconds': timeoutSeconds,
        if (multipartParts.isNotEmpty)
          'multipartParts': multipartParts.map((p) => p.toJson()).toList(),
      };

  factory Hook.fromJson(Map<String, dynamic> j) => Hook(
        id: j['id'] as String,
        key: j['key'] as String,
        name: j['name'] as String,
        enabled: (j['enabled'] as bool?) ?? true,
        spaceIds: ((j['spaceIds'] as List?) ?? const []).cast<String>().toSet(),
        triggers: ((j['triggers'] as List?) ?? const ['create', 'edit'])
            .cast<String>()
            .map((s) => HookTrigger.values.byName(s))
            .toSet(),
        postKinds: ((j['postKinds'] as List?) ?? const [])
            .cast<String>()
            .map((s) => PostKind.values.byName(s))
            .toSet(),
        tagFilters:
            ((j['tagFilters'] as List?) ?? const []).cast<String>().toSet(),
        method: (j['method'] as String?) ?? 'POST',
        urlTemplate: j['urlTemplate'] as String,
        headers:
            ((j['headers'] as Map?) ?? const {}).cast<String, String>(),
        bodyTemplate: j['bodyTemplate'] as String?,
        timeoutSeconds: (j['timeoutSeconds'] as int?) ?? 15,
        multipartParts: ((j['multipartParts'] as List?) ?? const [])
            .map((e) => HookMultipartPart.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );
}