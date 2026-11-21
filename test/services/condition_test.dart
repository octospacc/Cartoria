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

TemplateContext _ctx({Post? post}) => TemplateContext(
      post: post ?? _post(),
      space: _space(),
      hook: _hook(),
      trigger: HookTrigger.create,
    );

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
  });
}