import 'package:Cartoria/data/composer_draft.dart';
import 'package:Cartoria/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

ComposerDraft _draft({
  String body = '',
  PostKind kind = PostKind.note,
  String? url,
  String? title,
  String? description,
  String? thumbnail,
  List<String> fileIds = const [],
  DateTime? postDateTime,
  bool skipHooks = false,
}) =>
    ComposerDraft(
      fieldKey: 'test',
      kind: kind,
      body: body,
      url: url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      fileIds: fileIds,
      postDateTime: postDateTime,
      skipHooks: skipHooks,
      savedAt: DateTime.utc(2025, 1, 1),
    );

void main() {
  group('isEmpty', () {
    test('all defaults → empty', () {
      expect(_draft().isEmpty, isTrue);
    });

    test('non-empty body → not empty', () {
      expect(_draft(body: 'hi').isEmpty, isFalse);
    });

    test('non-empty url → not empty', () {
      expect(_draft(url: 'https://x').isEmpty, isFalse);
    });

    test('non-empty title → not empty', () {
      expect(_draft(title: 'T').isEmpty, isFalse);
    });

    test('non-empty description → not empty', () {
      expect(_draft(description: 'D').isEmpty, isFalse);
    });

    test('thumbnail set → not empty', () {
      expect(_draft(thumbnail: 'https://x/y.png').isEmpty, isFalse);
    });

    test('fileIds non-empty → not empty', () {
      expect(_draft(fileIds: ['f1']).isEmpty, isFalse);
    });

    test('postDateTime set → not empty', () {
      expect(_draft(postDateTime: DateTime.utc(2026)).isEmpty, isFalse);
    });

    test('skipHooks → not empty', () {
      expect(_draft(skipHooks: true).isEmpty, isFalse);
    });

    test('kind=bookmark → not empty', () {
      expect(_draft(kind: PostKind.bookmark).isEmpty, isFalse);
    });
  });

  group('toJson / fromJson round-trip', () {
    test('minimal draft', () {
      final d = _draft();
      final r = ComposerDraft.fromJson(d.toJson());
      expect(r.fieldKey, d.fieldKey);
      expect(r.kind, d.kind);
      expect(r.body, '');
      expect(r.url, isNull);
      expect(r.fileIds, isEmpty);
      expect(r.skipHooks, isFalse);
      expect(r.savedAt, d.savedAt);
    });

    test('full draft', () {
      final d = ComposerDraft(
        fieldKey: 'post:abc:edit',
        kind: PostKind.bookmark,
        body: 'Check this out',
        url: 'https://example.com',
        title: 'Example',
        description: 'A site',
        thumbnail: 'https://example.com/og.png',
        fileIds: ['f1', 'f2'],
        postDateTime: DateTime.utc(2025, 6, 1, 12),
        skipHooks: true,
        savedAt: DateTime.utc(2025, 1, 1),
      );
      final r = ComposerDraft.fromJson(d.toJson());
      expect(r.fieldKey, 'post:abc:edit');
      expect(r.kind, PostKind.bookmark);
      expect(r.body, 'Check this out');
      expect(r.url, 'https://example.com');
      expect(r.title, 'Example');
      expect(r.description, 'A site');
      expect(r.thumbnail, 'https://example.com/og.png');
      expect(r.fileIds, ['f1', 'f2']);
      expect(r.postDateTime, DateTime.utc(2025, 6, 1, 12));
      expect(r.skipHooks, isTrue);
    });

    test('missing optional fields on load → defaults', () {
      final r = ComposerDraft.fromJson({
        'fieldKey': 'x',
        'kind': 'note',
        'body': '',
        'savedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(r.url, isNull);
      expect(r.title, isNull);
      expect(r.fileIds, isEmpty);
      expect(r.skipHooks, isFalse);
    });

    test('kind defaults to note when absent', () {
      final r = ComposerDraft.fromJson({
        'fieldKey': 'x',
        'body': '',
        'savedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(r.kind, PostKind.note);
    });
  });

  group('bodyDelta', () {
    test('round-trips a quill-style delta string', () {
      const delta =
          '[{"insert":"hello"},{"insert":"world","attributes":{"bold":true}}]';
      final d = ComposerDraft(
        fieldKey: 'post:abc:edit',
        kind: PostKind.note,
        body: 'helloworld',
        bodyDelta: delta,
        savedAt: DateTime.utc(2025, 1, 1),
      );
      final r = ComposerDraft.fromJson(d.toJson());
      expect(r.bodyDelta, delta);
      expect(r.body, 'helloworld');
    });

    test('legacy draft (no bodyDelta key) loads with null bodyDelta', () {
      final r = ComposerDraft.fromJson({
        'fieldKey': 'x',
        'kind': 'note',
        'body': 'text',
        'savedAt': '2025-01-01T00:00:00.000Z',
      });
      expect(r.bodyDelta, isNull);
    });

    test('plaintext draft with empty bodyDelta is treated as empty', () {
      final d = ComposerDraft(
        fieldKey: 'x',
        kind: PostKind.note,
        body: '',
        bodyDelta: '',
        savedAt: DateTime.utc(2025),
      );
      expect(d.isEmpty, isTrue);
    });

    test('minimal quill empty-doc delta is treated as empty', () {
      // The Quill "empty document" serialisation. A composer with no
      // text should not be considered a draft with content, otherwise
      // every edit that gets cancelled persists a bogus draft.
      final d = ComposerDraft(
        fieldKey: 'x',
        kind: PostKind.note,
        body: '',
        bodyDelta: '[{"insert":"\\n"}]',
        savedAt: DateTime.utc(2025),
      );
      expect(d.isEmpty, isTrue);
    });

    test('minimal delta with whitespace is still minimal', () {
      final d = ComposerDraft(
        fieldKey: 'x',
        kind: PostKind.note,
        body: '',
        bodyDelta: '[\n  {"insert":"\\n"}\n]',
        savedAt: DateTime.utc(2025),
      );
      expect(d.isEmpty, isTrue);
    });

    test('delta with content is not empty', () {
      final d = ComposerDraft(
        fieldKey: 'x',
        kind: PostKind.note,
        body: '',
        bodyDelta: '[{"insert":"hi\\n"}]',
        savedAt: DateTime.utc(2025),
      );
      expect(d.isEmpty, isFalse);
    });

    test('non-empty body but empty delta is not empty', () {
      final d = ComposerDraft(
        fieldKey: 'x',
        kind: PostKind.note,
        body: 'text',
        bodyDelta: '[{"insert":"\\n"}]',
        savedAt: DateTime.utc(2025),
      );
      expect(d.isEmpty, isFalse);
    });
  });
}