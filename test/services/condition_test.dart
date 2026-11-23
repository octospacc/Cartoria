import 'package:Cartoria/data/hooks.dart';
import 'package:Cartoria/data/models.dart';
import 'package:Cartoria/data/services/condition.dart';
import 'package:Cartoria/data/services/template.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({
  PostKind kind = PostKind.note,
  List<String> fileIds = const [],
  String body = '<p>hi</p>',
}) =>
    Post(
      id: 'p1',
      kind: kind,
      body: body,
      fileIds: fileIds,
      createdAt: DateTime.utc(2024),
    );

Space _space() => Space(
      id: 's1',
      name: 'Test',
      icon: '📓',
      createdAt: DateTime.utc(2024),
    );

Hook _hook() => const Hook(
      id: 'h1',
      key: 'test',
      name: 'Test',
      rules: [],
    );

DriveFile _file(String id) => DriveFile(
      id: id,
      name: '$id.bin',
      sizeBytes: 0,
      createdAt: DateTime.utc(2024),
    );

/// Builds a context whose `files` list is derived from the post's
/// `fileIds`, mirroring what a real hook execution does: only
/// successfully-resolved `DriveFile`s land in `files`. A `fileIds`
/// entry with no matching `DriveFile` is a "missing" attachment and
/// contributes 0 to `post.files.length`.
TemplateContext _ctx({Post? post}) {
  final p = post ?? _post();
  return TemplateContext(
    post: p,
    space: _space(),
    hook: _hook(),
    trigger: HookTrigger.create,
    files: p.fileIds.map(_file).toList(),
  );
}

void main() {
  group('ConditionEvaluator.evaluate', () {
    test('null or empty → true', () {
      final ctx = _ctx();
      expect(ConditionEvaluator.evaluate(null, ctx), isTrue);
      expect(ConditionEvaluator.evaluate('', ctx), isTrue);
      expect(ConditionEvaluator.evaluate('   ', ctx), isTrue);
    });

    test('literal true / false', () {
      final ctx = _ctx();
      expect(ConditionEvaluator.evaluate('true', ctx), isTrue);
      expect(ConditionEvaluator.evaluate('false', ctx), isFalse);
    });

    test('numeric comparison', () {
      final ctx = _ctx();
      expect(ConditionEvaluator.evaluate('1 == 1', ctx), isTrue);
      expect(ConditionEvaluator.evaluate('1 != 2', ctx), isTrue);
      expect(ConditionEvaluator.evaluate('2 > 1', ctx), isTrue);
      expect(ConditionEvaluator.evaluate('2 < 1', ctx), isFalse);
      expect(ConditionEvaluator.evaluate('2 >= 2', ctx), isTrue);
      expect(ConditionEvaluator.evaluate('2 <= 1', ctx), isFalse);
    });

    test('post.kind comparison', () {
      expect(
        ConditionEvaluator.evaluate('post.kind == "note"', _ctx()),
        isTrue,
      );
      expect(
        ConditionEvaluator.evaluate(
            'post.kind == "bookmark"', _ctx(post: _post(kind: PostKind.bookmark))),
        isTrue,
      );
    });

    test('post.files.length predicates', () {
      expect(
        ConditionEvaluator.evaluate(
            'post.files.length == 0', _ctx(post: _post(fileIds: const []))),
        isTrue,
      );
      expect(
        ConditionEvaluator.evaluate(
            'post.files.length > 0', _ctx(post: _post(fileIds: const ['f1']))),
        isTrue,
      );
      expect(
        ConditionEvaluator.evaluate(
            'post.files.length >= 2', _ctx(post: _post(fileIds: const ['f1']))),
        isFalse,
      );
    });

    test('post.files.length counts resolved files, not fileIds', () {
      // A post that references f1 and f2, but only f1 resolves
      // (f2's DriveFile is missing/deleted). The hook executor sees 1
      // file — the attachments that would actually upload — not 2.
      // This test locks that semantic in: a change to `TemplateContext`
      // that switched `post.files.length` to `post.fileIds.length`
      // would break it.
      final post = _post(fileIds: const ['f1', 'f2']);
      final partialCtx = TemplateContext(
        post: post,
        space: _space(),
        hook: _hook(),
        trigger: HookTrigger.create,
        files: [_file('f1')],
      );
      expect(
        ConditionEvaluator.evaluate('post.files.length == 1', partialCtx),
        isTrue,
      );
      expect(
        ConditionEvaluator.evaluate('post.files.length == 2', partialCtx),
        isFalse,
      );
    });

    test('&& and || combine', () {
      final ctx = _ctx();
      expect(
        ConditionEvaluator.evaluate(
            'post.kind == "note" && post.files.length == 0', ctx),
        isTrue,
      );
      expect(
        ConditionEvaluator.evaluate(
            'post.kind == "bookmark" || post.kind == "note"', ctx),
        isTrue,
      );
      expect(
        ConditionEvaluator.evaluate(
            'post.kind == "bookmark" && post.files.length == 0', ctx),
        isFalse,
      );
    });

    test('parenthesised groups', () {
      expect(
        ConditionEvaluator.evaluate(
            '(1 == 1) && (2 == 2)', _ctx()),
        isTrue,
      );
    });

    test('malformed expression → true (fail-open)', () {
      expect(
        ConditionEvaluator.evaluate('this is not valid syntax', _ctx()),
        isTrue,
      );
    });

    test('string equality with double quotes', () {
      expect(
        ConditionEvaluator.evaluate('post.kind == "note"', _ctx()),
        isTrue,
      );
    });

    test('string equality with single quotes', () {
      expect(
        ConditionEvaluator.evaluate("post.kind == 'note'", _ctx()),
        isTrue,
      );
    });

    test('string inequality', () {
      expect(
        ConditionEvaluator.evaluate('post.kind != "bookmark"', _ctx()),
        isTrue,
      );
    });

    test('nested parentheses', () {
      expect(
        ConditionEvaluator.evaluate(
            '((1 == 1) && (2 == 2)) || false', _ctx()),
        isTrue,
      );
    });

    test('mixed && and || precedence', () {
      // && binds tighter than || in the parser; verify with a
      // case that would differ if precedence were reversed.
      expect(
        ConditionEvaluator.evaluate(
            'false && true || true', _ctx()),
        isTrue,
      );
    });

    test('non-numeric comparison falls back to string equality', () {
      expect(
        ConditionEvaluator.evaluate('"abc" == "abc"', _ctx()),
        isTrue,
      );
      expect(
        ConditionEvaluator.evaluate('"abc" == "xyz"', _ctx()),
        isFalse,
      );
    });

    test('malformed comparison → fail-open (true)', () {
      expect(
        ConditionEvaluator.evaluate('a === b', _ctx()),
        isTrue,
      );
    });

    test('empty parentheses → fail-open', () {
      expect(
        ConditionEvaluator.evaluate('()', _ctx()),
        isTrue,
      );
    });
  });
}