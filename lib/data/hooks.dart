import '../data/models.dart';

enum HookTrigger { create, edit }

// ── Hook rule ──────────────────────────────────────────────────────────────

/// One branch of a hook. The first rule whose [when] evaluates truthy
/// executes; the rest are skipped. An empty [when] always matches.
///
/// A rule is a complete request spec — method, URL, headers, body or
/// multipart parts. Splitting the request shape out of [Hook] lets one
/// hook dispatch to `sendMessage` / `sendPhoto` / `sendMediaGroup` without
/// the app knowing those methods exist.
class HookRule {
  /// Boolean expression, evaluated against [TemplateContext]. Null or
  /// empty means "always match". Grammar documented in
  /// `services/condition.dart`.
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

  /// Builds a single rule from the pre-rules hook format, so existing
  /// `hooks.json` files load without manual migration.
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

// ── Multipart part (extended) ──────────────────────────────────────────────

/// One field in a multipart/form-data request.
///
/// Three shapes:
///   - text field:       [template] set, [filePath] null, [repeat] null
///   - file field:       [filePath] set, [template] null, [repeat] null
///   - repeated field:   [repeat] set; produces N parts (or one joined
///                       field when [join] is set)
///
/// [name] and [template] support `{{repeat.index}}` and
/// `{{repeat.file.*}}` when [repeat] is set — see `services/template.dart`.
class HookMultipartPart {
  final String name;
  final String? template;

  /// Path into [TemplateContext] that resolves to a file ID. Examples:
  /// `post.files.0.id` (first attachment) or `repeat.file.id` (inside a
  /// repeated part). The executor reads bytes via the file resolver.
  final String? filePath;

  /// Optional filename override on the upload. Supports the same
  /// `{{repeat.*}}` tokens as [name].
  final String? filename;

  /// Path into [TemplateContext] that resolves to a list. Today only
  /// `post.files` is supported; the field is a string so the model doesn't
  /// hard-code it.
  final String? repeat;

  /// When set, all [repeat] iterations render into a single field named
  /// [name] (which must not contain `{{repeat.index}}`); their rendered
  /// values are concatenated with this string between them.
  final String? join;

  /// Optional prefix / suffix wrapped around a joined field. Useful for
  /// producing a JSON array: prefix `[`, suffix `]`.
  final String? prefix;
  final String? suffix;

  const HookMultipartPart({
    required this.name,
    this.template,
    this.filePath,
    this.filename,
    this.repeat,
    this.join,
    this.prefix,
    this.suffix,
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
      );
}

// ── Hook ───────────────────────────────────────────────────────────────────

class Hook {
  final String id;
  final String key;
  final String name;
  final bool enabled;
  final Set<String> spaceIds;
  final Set<HookTrigger> triggers;
  final Set<PostKind> postKinds;
  final Set<String> tagFilters;

  /// Ordered list of branches. First rule whose `when` matches executes.
  final List<HookRule> rules;

  final int timeoutSeconds;

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
    );
  }
}