import 'package:Cartoria/util/html_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('escapeHtml / unescapeHtml', () {
    test('escapeHtml replaces HTML metacharacters', () {
      expect(escapeHtml('a < b & c > d "e" \'f\''),
          'a &lt; b &amp; c &gt; d &quot;e&quot; &#39;f&#39;');
    });

    test('unescapeHtml reverses escapeHtml', () {
      const raw = 'a < b & c > d "e" \'f\'';
      expect(unescapeHtml(escapeHtml(raw)), raw);
    });

    test('&amp; is unescaped last so &amp;lt; stays &lt;', () {
      expect(unescapeHtml('&amp;lt;'), '&lt;');
    });
  });

  group('bodyToHtml', () {
    test('empty input → empty output', () {
      expect(bodyToHtml(''), '');
      expect(bodyToHtml('   '), '');
    });

    test('single line becomes one paragraph', () {
      expect(bodyToHtml('hello'), '<p>hello</p>');
    });

    test('multi-line inside one paragraph becomes <br>', () {
      expect(bodyToHtml('a\nb'), '<p>a<br>b</p>');
    });

    test('blank line separates paragraphs', () {
      expect(bodyToHtml('a\n\nb'), '<p>a</p>\n<p>b</p>');
    });

    test('HTML in input is escaped', () {
      expect(bodyToHtml('<b>x</b>'), '<p>&lt;b&gt;x&lt;/b&gt;</p>');
    });
  });

  group('bodyFromHtml', () {
    test('empty input → empty output', () {
      expect(bodyFromHtml(''), '');
    });

    test('paragraphs become blank-line separated', () {
      expect(bodyFromHtml('<p>a</p><p>b</p>'), 'a\n\nb');
    });

    test('<br> becomes single newline', () {
      expect(bodyFromHtml('<p>a<br>b</p>'), 'a\nb');
    });

    test('unknown tags are stripped', () {
      expect(bodyFromHtml('<p><span>x</span></p>'), 'x');
    });

    test('HTML entities are unescaped', () {
      expect(bodyFromHtml('<p>a &amp; b</p>'), 'a & b');
    });

    test('<hr> becomes em-dash line', () {
      expect(bodyFromHtml('<p>a</p><hr><p>b</p>'), 'a\n\n—\n\nb');
    });
  });

  group('frontmatter', () {
    test('makeDocument + parseFrontmatterMeta round-trip', () {
      const meta = {'id': 'abc', 'kind': 'note', 'n': 3};
      final doc = makeDocument(meta, '<p>hello</p>');
      expect(parseFrontmatterMeta(doc), meta);
    });

    test('bodyAfterFrontmatter returns the body', () {
      final doc = makeDocument({'id': 'abc'}, '<p>hello</p>');
      expect(bodyAfterFrontmatter(doc).trim(), '<p>hello</p>');
    });

    test('parseFrontmatterMeta throws on unclosed block', () {
      expect(
        () => parseFrontmatterMeta('<!---\n{}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('non-frontmatter input returns empty map', () {
      expect(parseFrontmatterMeta('<p>hi</p>'), isEmpty);
    });
  });
}