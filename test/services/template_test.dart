import 'package:Cartoria/data/hooks.dart';
import 'package:Cartoria/data/models.dart';
import 'package:Cartoria/data/services/template.dart';
import 'package:flutter_test/flutter_test.dart';

TemplateContext _ctx({
  String id = 'p1',
  String body = '<p>hello</p>',
  String? title,
  String? url,
  List<String> fileIds = const [],
}) =>
    TemplateContext(
      post: Post(
        id: id,
        kind: PostKind.note,
        body: body,
        title: title,
        url: url,
        fileIds: fileIds,
        createdAt: DateTime.utc(2024),
      ),
      space: Space(
        id: 's1',
        name: 'Space',
        icon: '📓',
        createdAt: DateTime.utc(2024),
      ),
      hook: const Hook(id: 'h1', key: 'k', name: 'H', rules: []),
      trigger: HookTrigger.create,
    );

void main() {
  group('TemplateRenderer.render', () {
    test('substitutes a simple path', () {
      expect(TemplateRenderer.render('{{post.id}}', _ctx()), 'p1');
    });

    test('literal text is preserved', () {
      expect(
        TemplateRenderer.render('id is {{post.id}}!', _ctx()),
        'id is p1!',
      );
    });

    test('|| falls back to the next non-empty value', () {
      expect(
        TemplateRenderer.render(
            '{{post.title || post.body}}', _ctx()),
        'hello',
      );
    });

    test('missing path becomes empty string', () {
      expect(
        TemplateRenderer.render('[{{post.nonexistent}}]', _ctx()),
        '[]',
      );
    });

    test('| upper uppercases', () {
      expect(
        TemplateRenderer.render(
            '{{post.title | upper}}', _ctx(title: 'hi')),
        'HI',
      );
    });

    test('| lower lowercases', () {
      expect(
        TemplateRenderer.render(
            '{{post.title | lower}}', _ctx(title: 'HI')),
        'hi',
      );
    });

    test('| default substitutes when the value is empty', () {
      expect(
        TemplateRenderer.render(
            '{{post.title | default(value="fallback")}}', _ctx()),
        'fallback',
      );
      expect(
        TemplateRenderer.render(
            '{{post.title | default(value="fallback")}}', _ctx(title: 'hi')),
        'hi',
      );
    });

    test('| wrap surrounds a non-empty value', () {
      expect(
        TemplateRenderer.render(
            '{{post.title | wrap(prefix="<", suffix=">")}}',
            _ctx(title: 'hi')),
        '<hi>',
      );
      // Empty value stays empty (no wrapper around nothing).
      expect(
        TemplateRenderer.render(
            '{{post.title | wrap(prefix="<", suffix=">")}}', _ctx()),
        '',
      );
    });

    test('URL escape encodes special characters', () {
      expect(
        TemplateRenderer.render(
            '{{post.title}}',
            _ctx(title: 'a b/c?'),
            escape: TemplateEscape.url),
        'a%20b%2Fc%3F',
      );
    });

    test('JSON escape escapes quotes and backslashes', () {
      expect(
        TemplateRenderer.render(
            '{{post.title}}',
            _ctx(title: 'a "b" c'),
            escape: TemplateEscape.json),
        r'a \"b\" c',
      );
    });

    test('triple braces bypass escaping', () {
      expect(
        TemplateRenderer.render(
            '{{{post.title}}}',
            _ctx(title: 'a "b"'),
            escape: TemplateEscape.url),
        'a "b"',
      );
    });
  });

  group('TemplateRenderer.render — pipeline edge cases', () {
    test('multiple pipeline stages compose', () {
      expect(
        TemplateRenderer.render(
          '{{post.title | upper | wrap(prefix="[", suffix="]")}}',
          _ctx(title: 'hi'),
        ),
        '[HI]',
      );
    });

    test('default with non-empty value keeps value', () {
      expect(
        TemplateRenderer.render(
          '{{post.title | default(value="x")}}',
          _ctx(title: 'real'),
        ),
        'real',
      );
    });

    test('quoted arg with comma', () {
      expect(
        TemplateRenderer.render(
          '{{post.title | default(value="a,b")}}',
          _ctx(),
        ),
        'a,b',
      );
    });

    test('unknown function leaves value unchanged', () {
      expect(
        TemplateRenderer.render(
          '{{post.title | nonexistent}}',
          _ctx(title: 'hi'),
        ),
        'hi',
      );
    });

    test('multiple substitutions in one template', () {
      expect(
        TemplateRenderer.render(
          '{{post.id}} - {{post.title}}',
          _ctx(id: 'p1', title: 'hi'),
        ),
        'p1 - hi',
      );
    });

    test('empty output for missing path', () {
      expect(
        TemplateRenderer.render('{{post.missing}}', _ctx()),
        '',
      );
    });

    test('URL escape percent-encodes space and slash', () {
      expect(
        TemplateRenderer.render(
          '{{post.title}}',
          _ctx(title: 'a b/c'),
          escape: TemplateEscape.url,
        ),
        'a%20b%2Fc',
      );
    });

    test('triple braces bypass URL escaping', () {
      expect(
        TemplateRenderer.render(
          '{{{post.title}}}',
          _ctx(title: 'a b/c'),
          escape: TemplateEscape.url,
        ),
        'a b/c',
      );
    });
  });
}