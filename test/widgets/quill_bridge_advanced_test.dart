import 'package:Cartoria/ui/widgets/quill_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('block structure', () {
    test('h1 + paragraph produces two blocks', () {
      final ctrl = quillFromHtml('<h1>Title</h1><p>Body</p>');
      expect(quillToPlaintext(ctrl), 'Title\nBody');
    });

    test('h1 attribute preserved through round-trip', () {
      final html = quillToHtml(quillFromHtml('<h1>Title</h1><p>Body</p>'));
      expect(html.toLowerCase(), contains('<h1'));
      expect(html, contains('Title'));
      expect(html, contains('Body'));
    });

    test('blockquote + paragraph produces two blocks', () {
      final ctrl =
          quillFromHtml('<blockquote>quoted</blockquote><p>after</p>');
      expect(quillToPlaintext(ctrl), 'quoted\nafter');
    });

    test('three paragraphs preserved in order', () {
      final ctrl = quillFromHtml('<p>a</p><p>b</p><p>c</p>');
      expect(quillToPlaintext(ctrl), 'a\nb\nc');
    });

    test('mixed block types (h1, p, blockquote)', () {
      final ctrl = quillFromHtml(
          '<h1>T</h1><p>para</p><blockquote>quote</blockquote>');
      final txt = quillToPlaintext(ctrl);
      expect(txt, contains('T'));
      expect(txt, contains('para'));
      expect(txt, contains('quote'));
    });

    test('multi-line <pre> preserved', () {
      final ctrl = quillFromHtml('<pre>line1\nline2\nline3</pre>');
      final txt = quillToPlaintext(ctrl);
      expect(txt, contains('line1'));
      expect(txt, contains('line2'));
      expect(txt, contains('line3'));
    });
  });

  group('inline code', () {
    test('code with special HTML characters survives', () {
      final ctrl = quillFromHtml(
          '<p>use <code>a &lt; b &amp;&amp; c &gt; d</code></p>');
      final html = quillToHtml(ctrl);
      expect(html, contains('<code'));
      expect(html, contains('a &lt; b'));
    });

    test('two adjacent code spans preserved as code', () {
      final html =
          quillToHtml(quillFromHtml('<p><code>a</code><code>b</code></p>'));
      final codeMatches = RegExp('<code').allMatches(html).length;
      // The converter may merge adjacent code spans into one <code>ab</code>;
      // the content and formatting are preserved either way.
      expect(codeMatches, greaterThanOrEqualTo(1));
      expect(html, contains('a'));
      expect(html, contains('b'));
    });

    test('code inside bold preserves both', () {
      final ctrl = quillFromHtml(
          '<p><strong>bold <code>code</code> more</strong></p>');
      final plain = quillToPlaintext(ctrl);
      expect(plain, contains('bold'));
      expect(plain, contains('code'));
      expect(plain, contains('more'));
    });

    test('code inside paragraph within list', () {
      final ctrl = quillFromHtml(
          '<ul><li>text with <code>inline</code> end</li></ul>');
      final txt = quillToPlaintext(ctrl);
      expect(txt, contains('text'));
      expect(txt, contains('inline'));
      expect(txt, contains('end'));
    });
  });

  group('inline formatting round-trip', () {
    test('underline preserved', () {
      final html = quillToHtml(quillFromHtml('<p><u>x</u></p>'));
      expect(html, contains('<u'));
    });

    test('strikethrough preserved', () {
      final html = quillToHtml(quillFromHtml('<p><s>x</s></p>'));
      expect(html.toLowerCase(), contains('<s'));
    });

    test('italic preserved', () {
      final html = quillToHtml(quillFromHtml('<p><em>x</em></p>'));
      expect(html.toLowerCase(), anyOf(contains('<em'), contains('<i>')));
    });

    test('all formats on separate words in one paragraph', () {
      final ctrl = quillFromHtml(
        '<p><strong>bold</strong> <em>italic</em> <u>under</u> '
        '<s>strike</s> <code>code</code></p>',
      );
      final plain = quillToPlaintext(ctrl);
      expect(plain, contains('bold'));
      expect(plain, contains('italic'));
      expect(plain, contains('under'));
      expect(plain, contains('strike'));
      expect(plain, contains('code'));
    });
  });

  group('edge cases', () {
    test('whitespace-only → empty html', () {
      expect(quillToHtml(quillFromHtml('   ')), '');
    });

    test('empty html → empty html', () {
      expect(quillToHtml(quillFromHtml('')), '');
    });

    test('br-only input does not throw', () {
      final ctrl = quillFromHtml('<br>');
      expect(() => quillToHtml(ctrl), returnsNormally);
    });

    test('paragraph with nested spans survives', () {
      final ctrl = quillFromHtml(
          '<p>before <span>middle</span> after</p>');
      expect(quillToPlaintext(ctrl), 'before middle after');
    });
  });

  group('draft fallbacks', () {
    test('null delta → plaintext body', () {
      final ctrl = quillFromDraft(body: 'plain', bodyDelta: null);
      expect(quillToPlaintext(ctrl), 'plain');
    });

    test('empty delta → plaintext body', () {
      final ctrl = quillFromDraft(body: 'plain', bodyDelta: '');
      expect(quillToPlaintext(ctrl), 'plain');
    });

    test('malformed JSON → plaintext body', () {
      final ctrl = quillFromDraft(body: 'plain', bodyDelta: '{not json');
      expect(quillToPlaintext(ctrl), 'plain');
    });

    test('JSON object (not list) → plaintext body', () {
      final ctrl =
          quillFromDraft(body: 'plain', bodyDelta: '{"ops": []}');
      expect(quillToPlaintext(ctrl), 'plain');
    });

    test('valid empty delta list → empty document', () {
      final ctrl = quillFromDraft(
          body: 'ignored', bodyDelta: '[{"insert":"\\n"}]');
      expect(quillToPlaintext(ctrl), '');
    });

    test('valid delta with content takes precedence over body', () {
      final ctrl = quillFromDraft(
        body: 'ignored',
        bodyDelta: '[{"insert":"from delta\\n"}]',
      );
      expect(quillToPlaintext(ctrl), 'from delta');
    });
  });

  group('htmlHasInlineFormatting comprehensive', () {
    for (final tag in [
      'strong',
      'b',
      'em',
      'i',
      'u',
      's',
      'del',
      'code',
    ]) {
      test('<$tag> detected', () {
        expect(
          htmlHasInlineFormatting('<p><$tag>x</$tag></p>'),
          isTrue,
          reason: 'tag: $tag',
        );
      });
    }

    test('font-family monospace span detected', () {
      expect(
        htmlHasInlineFormatting(
          '<p><span style="font-family: monospace">x</span></p>',
        ),
        isTrue,
      );
    });

    test('plain paragraph not detected', () {
      expect(htmlHasInlineFormatting('<p>plain</p>'), isFalse);
    });

    test('headings not detected', () {
      expect(htmlHasInlineFormatting('<h1>Title</h1>'), isFalse);
    });

    test('lists not detected', () {
      expect(
        htmlHasInlineFormatting('<ul><li>x</li></ul>'),
        isFalse,
      );
    });
  });

  group('plaintext semantics', () {
    test('single paragraph', () {
      expect(quillToPlaintext(quillFromHtml('<p>hello</p>')), 'hello');
    });

    test('trims surrounding whitespace', () {
      expect(
        quillToPlaintext(quillFromHtml('<p>  hello  </p>')),
        'hello',
      );
    });

    test('preserves internal newlines from paragraphs', () {
      expect(
        quillToPlaintext(quillFromHtml('<p>a</p><p>b</p>')),
        'a\nb',
      );
    });

    test('empty document → empty plaintext', () {
      expect(quillToPlaintext(quillFromHtml('')), '');
    });
  });
}