import '../data/models.dart';

enum HookTrigger { create, edit }

/// One field in a multipart/form-data request.
///
/// Three shapes:
///   - text field:       [template] set, [filePath] null, [repeat] null
///   - file field:       [filePath] set, [template] null, [repeat] null
///   - repeated field:   [repeat] set; produces N parts (or one joined
///                       field when [join] is set)
///
/// When [skipIfEmpty] is true and the rendered value is the empty string,
/// the part is omitted from the request entirely. Useful for optional
/// JSON-envelope fields like Telegram's `reply_parameters` that must not
/// appear at all (rather than as `{}`) when there's nothing to send.
class HookMultipartPart {
  final String name;
  final String? template;
  final String? filePath;
  final String? filename;
  final String? repeat;
  final String? join;
  final String? prefix;
  final String? suffix;
  final bool skipIfEmpty;

  const HookMultipartPart({
    required this.name,
    this.template,
    this.filePath,
    this.filename,
    this.repeat,
    this.join,
    this.prefix,
    this.suffix,
    this.skipIfEmpty = false,
  }) : assert(
          (template != null) != (filePath != null),
          'Exactly one of template or filePath must be set',
        ),
        assert(
          join == null || repeat != null,
          'join requires repeat',
        ),
        assert(
          (prefix == null && suffix == null) || join != null,
          'prefix/suffix require join',
        );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (template != null) 'template': template,
        if (filePath != null) 'filePath': filePath,
        if (filename != null) 'filename': filename,
        if (repeat != null) 'repeat': repeat,
        if (join != null) 'join': join,
        if (prefix != null) 'prefix': prefix,
        if (suffix != null) 'suffix': suffix,
        if (skipIfEmpty) 'skipIfEmpty': skipIfEmpty,
      };

  factory HookMultipartPart.fromJson(Map<String, dynamic> j) =>
      HookMultipartPart(
        name: j['name'] as String,
        template: j['template'] as String?,
        filePath: j['filePath'] as String?,
        filename: j['filename'] as String?,
        repeat: j['repeat'] as String?,
        join: j['join'] as String?,
        prefix: j['prefix'] as String?,
        suffix: j['suffix'] as String?,
        skipIfEmpty: (j['skipIfEmpty'] as bool?) ?? false,
      );
}

class HookRule {
  final String? when;
  final String method;
  final String urlTemplate;
  final Map<String, String> headers;
  final String? bodyTemplate;
  final List<HookMultipartPart> multipartParts;

  const HookRule({
    this.when,
    this.method = 'POST',
    required this.urlTemplate,
    this.headers = const {},
    this.bodyTemplate,
    this.multipartParts = const [],
  });

  Map<String, dynamic> toJson() => {
        if (when != null && when!.isNotEmpty) 'when': when,
        'method': method,
        'urlTemplate': urlTemplate,
        'headers': headers,
        if (bodyTemplate != null) 'bodyTemplate': bodyTemplate,
        if (multipartParts.isNotEmpty)
          'multipartParts': multipartParts.map((p) => p.toJson()).toList(),
      };

  factory HookRule.fromJson(Map<String, dynamic> j) => HookRule(
        when: j['when'] as String?,
        method: (j['method'] as String?) ?? 'POST',
        urlTemplate: j['urlTemplate'] as String,
        headers:
            ((j['headers'] as Map?) ?? const {}).cast<String, String>(),
        bodyTemplate: j['bodyTemplate'] as String?,
        multipartParts: ((j['multipartParts'] as List?) ?? const [])
            .map((e) => HookMultipartPart.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
      );

  factory HookRule.fromLegacy(Map<String, dynamic> j) => HookRule(
        method: (j['method'] as String?) ?? 'POST',
        urlTemplate: j['urlTemplate'] as String,
        headers:
            ((j['headers'] as Map?) ?? const {}).cast<String, String>(),
        bodyTemplate: j['bodyTemplate'] as String?,
        multipartParts: ((j['multipartParts'] as List?) ?? const [])
            .map((e) => HookMultipartPart.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList(),
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
  final List<HookRule> rules;
  final int timeoutSeconds;

  /// Named constants available to templates as `{{vars.<name>}}`.
  /// Values are literal — they are not re-interpolated, so a value
  /// containing `{{...}}` renders as the literal text. Useful for
  /// tokens, chat IDs, base URLs, or anything reused across several
  /// rules.
  final Map<String, String> variables;

  const Hook({
    required this.id,
    required this.key,
    required this.name,
    this.enabled = true,
    this.spaceIds = const {},
    this.triggers = const {HookTrigger.create, HookTrigger.edit},
    this.postKinds = const {},
    this.tagFilters = const {},
    required this.rules,
    this.timeoutSeconds = 15,
    this.variables = const {},
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
        rules: rules,
        timeoutSeconds: timeoutSeconds,
        variables: variables,
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
        'timeoutSeconds': timeoutSeconds,
        if (variables.isNotEmpty) 'variables': variables,
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  factory Hook.fromJson(Map<String, dynamic> j) {
    final rawRules = j['rules'] as List?;
    final rules = rawRules != null
        ? rawRules
            .map((e) =>
                HookRule.fromJson((e as Map).cast<String, dynamic>()))
            .toList()
        : [HookRule.fromLegacy(j)];
    return Hook(
      id: j['id'] as String,
      key: j['key'] as String,
      name: j['name'] as String,
      enabled: (j['enabled'] as bool?) ?? true,
      spaceIds:
          ((j['spaceIds'] as List?) ?? const []).cast<String>().toSet(),
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
      rules: rules,
      timeoutSeconds: (j['timeoutSeconds'] as int?) ?? 15,
      variables: ((j['variables'] as Map?) ?? const {})
          .cast<String, String>(),
    );
  }
}