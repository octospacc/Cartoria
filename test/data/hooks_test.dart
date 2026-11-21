import 'package:Cartoria/data/hooks.dart';
import 'package:Cartoria/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HookMultipartPart round-trip', () {
    test('text field', () {
      const p = HookMultipartPart(name: 'chat_id', template: '{{vars.chat}}');
      final r = HookMultipartPart.fromJson(p.toJson());
      expect(r.name, 'chat_id');
      expect(r.template, '{{vars.chat}}');
      expect(r.filePath, isNull);
      expect(r.repeat, isNull);
      expect(r.skipIfEmpty, isFalse);
    });

    test('file field', () {
      const p = HookMultipartPart(name: 'photo', filePath: 'post.files.0.id');
      final r = HookMultipartPart.fromJson(p.toJson());
      expect(r.filePath, 'post.files.0.id');
      expect(r.template, isNull);
    });

    test('repeat with join, prefix, suffix', () {
      const p = HookMultipartPart(
        name: 'media',
        template: '{{repeat.file.name}}',
        repeat: 'post.files',
        join: ',',
        prefix: '[',
        suffix: ']',
      );
      final r = HookMultipartPart.fromJson(p.toJson());
      expect(r.repeat, 'post.files');
      expect(r.join, ',');
      expect(r.prefix, '[');
      expect(r.suffix, ']');
    });

    test('skipIfEmpty preserved', () {
      const p = HookMultipartPart(
        name: 'reply_parameters',
        template: '{{previous.x.json}}',
        skipIfEmpty: true,
      );
      final r = HookMultipartPart.fromJson(p.toJson());
      expect(r.skipIfEmpty, isTrue);
    });
  });

  group('HookRule round-trip', () {
    test('minimal rule', () {
      const r = HookRule(urlTemplate: 'https://example.com/hook');
      final r2 = HookRule.fromJson(r.toJson());
      expect(r2.urlTemplate, 'https://example.com/hook');
      expect(r2.method, 'POST');
      expect(r2.when, isNull);
      expect(r2.headers, isEmpty);
      expect(r2.multipartParts, isEmpty);
      expect(r2.bodyTemplate, isNull);
    });

    test('full rule', () {
      const r = HookRule(
        when: 'post.files.length > 0',
        method: 'PUT',
        urlTemplate: 'https://example.com/{{post.id}}',
        headers: {'Authorization': 'Bearer {{vars.token}}'},
        bodyTemplate: '{"title": "{{post.title}}"}',
        multipartParts: [
          HookMultipartPart(name: 'a', template: 'x'),
          HookMultipartPart(name: 'b', filePath: 'post.files.0.id'),
        ],
      );
      final r2 = HookRule.fromJson(r.toJson());
      expect(r2.when, 'post.files.length > 0');
      expect(r2.method, 'PUT');
      expect(r2.urlTemplate, r.urlTemplate);
      expect(r2.headers, r.headers);
      expect(r2.bodyTemplate, r.bodyTemplate);
      expect(r2.multipartParts, hasLength(2));
    });
  });

  group('Hook serialization', () {
    test('minimal Hook → JSON → Hook', () {
      const h = Hook(
        id: 'h1',
        key: 'test',
        name: 'Test hook',
        rules: [HookRule(urlTemplate: 'https://example.com')],
      );
      final h2 = Hook.fromJson(h.toJson());
      expect(h2.id, h.id);
      expect(h2.key, h.key);
      expect(h2.name, h.name);
      expect(h2.enabled, isTrue);
      expect(h2.triggers,
          {HookTrigger.create, HookTrigger.edit});
      expect(h2.rules, hasLength(1));
    });

    test('legacy single-rule format parses', () {
      final legacy = {
        'id': 'h1',
        'key': 'test',
        'name': 'Test',
        'urlTemplate': 'https://example.com/old',
        'method': 'GET',
      };
      final h = Hook.fromJson(legacy);
      expect(h.rules, hasLength(1));
      expect(h.rules.first.urlTemplate, 'https://example.com/old');
      expect(h.rules.first.method, 'GET');
    });

    test('full hook round-trip', () {
      const h = Hook(
        id: 'h1',
        key: 'telegram',
        name: 'Telegram',
        enabled: false,
        spaceIds: {'s1', 's2'},
        triggers: {HookTrigger.create},
        postKinds: {PostKind.note},
        tagFilters: {'news'},
        timeoutSeconds: 30,
        variables: {'bot_token': 'abc'},
        rules: [
          HookRule(
            when: 'post.kind == "note"',
            urlTemplate: 'https://api.telegram.org/bot{{vars.bot_token}}/sendMessage',
          ),
        ],
      );
      final h2 = Hook.fromJson(h.toJson());
      expect(h2.id, h.id);
      expect(h2.enabled, isFalse);
      expect(h2.spaceIds, {'s1', 's2'});
      expect(h2.triggers, {HookTrigger.create});
      expect(h2.postKinds, {PostKind.note});
      expect(h2.tagFilters, {'news'});
      expect(h2.timeoutSeconds, 30);
      expect(h2.variables, {'bot_token': 'abc'});
      expect(h2.rules, hasLength(1));
    });
  });

  group('Hook.matches', () {
    Hook build({
      bool enabled = true,
      Set<HookTrigger> triggers = const {HookTrigger.create},
      Set<String> spaceIds = const {},
      Set<PostKind> postKinds = const {},
      Set<String> tagFilters = const {},
    }) =>
        Hook(
          id: 'h1',
          key: 'k',
          name: 'n',
          enabled: enabled,
          triggers: triggers,
          spaceIds: spaceIds,
          postKinds: postKinds,
          tagFilters: tagFilters,
          rules: const [HookRule(urlTemplate: 'https://e')],
        );

    test('disabled hook never matches', () {
      expect(
        build(enabled: false).matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: const {},
        ),
        isFalse,
      );
    });

    test('trigger not in set → no match', () {
      expect(
        build(triggers: {HookTrigger.edit}).matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: const {},
        ),
        isFalse,
      );
    });

    test('empty spaceIds → any space matches', () {
      expect(
        build().matches(
          spaceId: 'any',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: const {},
        ),
        isTrue,
      );
    });

    test('spaceIds restricts matches', () {
      final h = build(spaceIds: {'s1'});
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: const {},
        ),
        isTrue,
      );
      expect(
        h.matches(
          spaceId: 's2',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: const {},
        ),
        isFalse,
      );
    });

    test('postKinds restricts matches', () {
      final h = build(postKinds: {PostKind.bookmark});
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.bookmark,
          postTags: const {},
        ),
        isTrue,
      );
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: const {},
        ),
        isFalse,
      );
    });

    test('tagFilters requires at least one intersecting tag', () {
      final h = build(tagFilters: {'news', 'tech'});
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: {'news'},
        ),
        isTrue,
      );
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: {'other'},
        ),
        isFalse,
      );
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: const {},
        ),
        isFalse,
      );
    });

    test('all filters combined', () {
      final h = build(
        spaceIds: {'s1'},
        postKinds: {PostKind.note},
        tagFilters: {'news'},
      );
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: {'news'},
        ),
        isTrue,
      );
      expect(
        h.matches(
          spaceId: 's2',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: {'news'},
        ),
        isFalse,
      );
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.bookmark,
          postTags: {'news'},
        ),
        isFalse,
      );
      expect(
        h.matches(
          spaceId: 's1',
          trigger: HookTrigger.create,
          postKind: PostKind.note,
          postTags: {'other'},
        ),
        isFalse,
      );
    });
  });

  group('Hook.withEnabled', () {
    test('returns a new instance with changed flag', () {
      const h = Hook(
        id: 'h1',
        key: 'k',
        name: 'n',
        enabled: true,
        rules: [],
      );
      final h2 = h.withEnabled(false);
      expect(h2.enabled, isFalse);
      expect(h.enabled, isTrue); // original unchanged
    });
  });
}