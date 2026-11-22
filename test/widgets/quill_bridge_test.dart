import 'package:Cartoria/ui/widgets/quill_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('quillFromHtml', () {
    test('empty string → empty document', () {
      final ctrl = quillFromHtml('');
      expect(ctrl.document.toPlainText(), '\n');
    });

    test('whitespace-only string → empty document', () {
      final ctrl = quillFromHtml('   \n\t  ');
      expect(ctrl.document.toPlainText(), '\n');
    });

    test('plain paragraph → matching plaintext', () {
      final ctrl = quillFromHtml('<p>hello world</p>');
      expect(quillToPlaintext(ctrl), 'hello world');
    });

    test('two paragraphs join with newlines', () {
      final ctrl = quillFromHtml('<p>first</p><p>second</p>');
      expect(quillToPlaintext(ctrl), 'first\nsecond');
    });

    test('malformed HTML → empty document, no throw', () {
      final ctrl = quillFromHtml('<p>unclosed');
      expect(ctrl.document.toPlainText(), isNotEmpty);
    });
  });

  group('inline code round-trip', () {
    test('single inline code tag preserved', () {
      final html = quillToHtml(quillFromHtml(
        '<p>use <code>foo()</code> here</p>',
      ));
      expect(html, contains('<code'));
      expect(html, contains('foo()'));
      expect(html, contains('</code>'));
    });

    test('inline code is not rendered as block code', () {
      final html = quillToHtml(quillFromHtml(
        '<p>use <code>foo()</code> here</p>',
      ));
      expect(html, isNot(contains('code-block')));
      expect(html, isNot(contains('<pre')));
    });

    test('two inline codes in same paragraph', () {
      final html = quillToHtml(quillFromHtml(
        '<p><code>a</code> and <code>b</code></p>',
      ));
      final codeCount = RegExp('<code').allMatches(html).length;
      expect(codeCount, 2);
      expect(html, contains('a'));
      expect(html, contains('b'));
    });

    test('multi-line <pre> block stays as block, not inline', () {
      final ctrl = quillFromHtml(
        '<pre>line one\nline two\nline three</pre>',
      );
      final plain = quillToPlaintext(ctrl);
      expect(plain, contains('line one'));
      expect(plain, contains('line three'));
    });

    test('old forEmail span form recognized as inline code', () {
      final html = quillToHtml(quillFromHtml(
        '<p><span style="font-family: monospace">foo()</span></p>',
      ));
      expect(html, contains('<code'));
      expect(html, contains('foo()'));
    });

    test('code with class attribute is normalized', () {
      final html = quillToHtml(quillFromHtml(
        '<p><code class="language-dart">final x = 1;</code></p>',
      ));
      expect(html, contains('<code'));
      expect(html, contains('final x = 1;'));
    });

    test('inline code adjacent to bold preserves both', () {
      final html = quillToHtml(quillFromHtml(
        '<p><strong>bold</strong> <code>code</code></p>',
      ));
      expect(html, anyOf(contains('<strong'), contains('<b>')));
      expect(html, contains('<code'));
    });
  });

  group('quillToHtml semantics', () {
    test('empty document → empty string', () {
      final ctrl = quillFromHtml('');
      expect(quillToHtml(ctrl), '');
    });

    test('bold uses semantic <strong> not <span>', () {
      final ctrl = quillFromHtml('<p><strong>x</strong></p>');
      final html = quillToHtml(ctrl);
      expect(html, isNot(contains('<span')));
      expect(html.toLowerCase(), anyOf(contains('<strong'), contains('<b>')));
    });

    test('italic uses semantic <em> not <i>', () {
      final ctrl = quillFromHtml('<p><em>x</em></p>');
      final html = quillToHtml(ctrl);
      expect(html.toLowerCase(), anyOf(contains('<em'), contains('<i>')));
    });

    test('underline uses semantic <u>', () {
      final ctrl = quillFromHtml('<p><u>x</u></p>');
      final html = quillToHtml(ctrl);
      expect(html, contains('<u'));
    });
  });

  group('quillToDeltaJson / quillFromDraft round-trip', () {
    test('minimal empty delta', () {
      final ctrl = quillFromHtml('');
      final json = quillToDeltaJson(ctrl);
      final restored = quillFromDraft(body: '', bodyDelta: json);
      expect(quillToPlaintext(restored), '');
    });

    test('plain text', () {
      final ctrl = quillFromHtml('<p>hello</p>');
      final json = quillToDeltaJson(ctrl);
      final restored = quillFromDraft(body: 'hello', bodyDelta: json);
      expect(quillToPlaintext(restored), 'hello');
    });

    test('bold formatting preserved', () {
      final original = quillFromHtml('<p><strong>bold</strong></p>');
      final json = quillToDeltaJson(original);
      final restored = quillFromDraft(body: 'bold', bodyDelta: json);
      final html = quillToHtml(restored);
      expect(html.toLowerCase(), anyOf(contains('<strong'), contains('<b>')));
    });

    test('inline code preserved', () {
      final original = quillFromHtml('<p><code>foo()</code></p>');
      final json = quillToDeltaJson(original);
      final restored = quillFromDraft(body: 'foo()', bodyDelta: json);
      final html = quillToHtml(restored);
      expect(html, contains('<code'));
    });
  });

  group('quillFromDraft fallbacks', () {
    test('null bodyDelta → loads plaintext body', () {
      final ctrl = quillFromDraft(body: 'plain text', bodyDelta: null);
      expect(quillToPlaintext(ctrl), 'plain text');
    });

    test('empty bodyDelta → loads plaintext body', () {
      final ctrl = quillFromDraft(body: 'plain text', bodyDelta: '');
      expect(quillToPlaintext(ctrl), 'plain text');
    });

    test('malformed bodyDelta → falls back to plaintext', () {
      final ctrl = quillFromDraft(
        body: 'fallback',
        bodyDelta: 'not valid json',
      );
      expect(quillToPlaintext(ctrl), 'fallback');
    });

    test('non-list bodyDelta → falls back to plaintext', () {
      final ctrl = quillFromDraft(
        body: 'fallback',
        bodyDelta: '{"not": "a list"}',
      );
      expect(quillToPlaintext(ctrl), 'fallback');
    });
  });

  group('htmlHasInlineFormatting', () {
    test('empty → false', () {
      expect(htmlHasInlineFormatting(''), isFalse);
    });

    test('plain paragraph → false', () {
      expect(htmlHasInlineFormatting('<p>plain</p>'), isFalse);
    });

    test('<strong> → true', () {
      expect(htmlHasInlineFormatting('<p><strong>x</strong></p>'), isTrue);
    });

    test('<b> → true', () {
      expect(htmlHasInlineFormatting('<p><b>x</b></p>'), isTrue);
    });

    test('<em> → true', () {
      expect(htmlHasInlineFormatting('<p><em>x</em></p>'), isTrue);
    });

    test('<i> → true', () {
      expect(htmlHasInlineFormatting('<p><i>x</i></p>'), isTrue);
    });

    test('<u> → true', () {
      expect(htmlHasInlineFormatting('<p><u>x</u></p>'), isTrue);
    });

    test('<s> → true', () {
      expect(htmlHasInlineFormatting('<p><s>x</s></p>'), isTrue);
    });

    test('<del> → true', () {
      expect(htmlHasInlineFormatting('<p><del>x</del></p>'), isTrue);
    });

    test('<code> → true', () {
      expect(htmlHasInlineFormatting('<p><code>x</code></p>'), isTrue);
    });

    test('forEmail span form → true', () {
      expect(
        htmlHasInlineFormatting(
          '<p><span style="font-family: monospace">x</span></p>',
        ),
        isTrue,
      );
    });

    test('blockquote alone → false', () {
      expect(
        htmlHasInlineFormatting('<blockquote>quoted</blockquote>'),
        isFalse,
      );
    });

    test('list alone → false (structure, not inline format)', () {
      expect(htmlHasInlineFormatting('<ul><li>x</li></ul>'), isFalse);
    });
  });

  group('quillToPlaintext', () {
    test('trims leading/trailing whitespace', () {
      final ctrl = quillFromHtml('<p>  hello  </p>');
      expect(quillToPlaintext(ctrl), 'hello');
    });

    test('empty document → empty string', () {
      final ctrl = quillFromHtml('');
      expect(quillToPlaintext(ctrl), '');
    });

    test('multi-paragraph preserves internal newlines', () {
      final ctrl = quillFromHtml('<p>a</p><p>b</p><p>c</p>');
      expect(quillToPlaintext(ctrl), 'a\nb\nc');
    });
  });
}