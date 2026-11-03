import '../data/models.dart';

enum HookTrigger { create, edit }

class Hook {
  final String id;
  final String key;         // user-visible, [a-z][a-z0-9_]*, unique per vault
  final String name;
  final bool enabled;
  final Set<String> spaceIds;         // empty = every space
  final Set<HookTrigger> triggers;
  final Set<PostKind> postKinds;      // empty = every kind
  final Set<String> tagFilters;       // empty = any tags; else at least one match
  final String method;                // GET/POST/PUT/PATCH/DELETE
  final String urlTemplate;
  final Map<String, String> headers;
  final String? bodyTemplate;
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
    this.method = 'POST',
    required this.urlTemplate,
    this.headers = const {},
    this.bodyTemplate,
    this.timeoutSeconds = 15,
  });

  Hook withEnabled(bool value) => Hook(
        id: id, key: key, name: name, enabled: value,
        spaceIds: spaceIds, triggers: triggers, postKinds: postKinds,
        tagFilters: tagFilters, method: method, urlTemplate: urlTemplate,
        headers: headers, bodyTemplate: bodyTemplate,
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
        'method': method,
        'urlTemplate': urlTemplate,
        'headers': headers,
        'bodyTemplate': bodyTemplate,
        'timeoutSeconds': timeoutSeconds,
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
        headers: ((j['headers'] as Map?) ?? const {})
            .cast<String, String>(),
        bodyTemplate: j['bodyTemplate'] as String?,
        timeoutSeconds: (j['timeoutSeconds'] as int?) ?? 15,
      );
}