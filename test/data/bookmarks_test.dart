import 'package:Cartoria/data/bookmarks.dart';
import 'package:flutter_test/flutter_test.dart';

String _wrap(String inner) => '''
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<TITLE>My Bookmarks</TITLE>
<H1>My Bookmarks</H1>
<DL><p>
$inner
</DL><p>
''';

void main() {
  group('BookmarkFileParser.parse', () {
    test('empty document → no bookmarks, no title', () {
      final f = BookmarkFileParser.parse('');
      expect(f.bookmarks, isEmpty);
      expect(f.title, isNull);
    });

    test('title from <TITLE>', () {
      final f = BookmarkFileParser.parse(_wrap(''));
      expect(f.title, 'My Bookmarks');
    });

    test('title falls back to <H1> when <TITLE> absent', () {
      final f = BookmarkFileParser.parse('''
<H1>Only H1</H1>
<DL><p>
<DT><A HREF="https://a">A</A>
</DL><p>
''');
      expect(f.title, 'Only H1');
    });

    test('single bookmark', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://example.com">Example</A>',
      ));
      expect(f.bookmarks, hasLength(1));
      final b = f.bookmarks.first;
      expect(b.url, 'https://example.com');
      expect(b.title, 'Example');
    });

    test('title falls back to href when anchor is empty', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://example.com"></A>',
      ));
      expect(f.bookmarks.first.title, 'https://example.com');
    });

    test('no href → skipped', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A>No link</A>',
      ));
      expect(f.bookmarks, isEmpty);
    });

    test('ADD_DATE parsed as seconds since epoch', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://example.com" ADD_DATE="1700000000">X</A>',
      ));
      final b = f.bookmarks.first;
      expect(b.createdAt.isUtc, isTrue);
      expect(b.createdAt.year, 2023);
      expect(b.createdAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('missing ADD_DATE → recent now()', () {
      final before = DateTime.now().toUtc();
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://example.com">X</A>',
      ));
      final after = DateTime.now().toUtc();
      final b = f.bookmarks.first;
      expect(b.createdAt.isBefore(before), isFalse);
      expect(b.createdAt.isAfter(after), isFalse);
    });

    test('TAGS attribute parsed and lowercased', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://example.com" TAGS="One,TWO">X</A>',
      ));
      expect(f.bookmarks.first.tags, ['one', 'two']);
    });

    test('DATA-COVER becomes thumbnail', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://example.com" '
        'DATA-COVER="https://img.example.com/x.png">X</A>',
      ));
      expect(f.bookmarks.first.thumbnail, 'https://img.example.com/x.png');
    });

    test('folder names become tags', () {
      final f = BookmarkFileParser.parse(_wrap('''
<DT><H3>Folder A</H3>
<DL><p>
<DT><A HREF="https://example.com">X</A>
</DL><p>
'''));
      expect(f.bookmarks, hasLength(1));
      expect(f.bookmarks.first.tags, contains('folder a'));
    });

    test('nested folders accumulate in tags', () {
      final f = BookmarkFileParser.parse(_wrap('''
<DT><H3>Outer</H3>
<DL><p>
<DT><H3>Inner</H3>
<DL><p>
<DT><A HREF="https://example.com">X</A>
</DL><p>
</DL><p>
'''));
      final tags = f.bookmarks.first.tags;
      expect(tags, contains('outer'));
      expect(tags, contains('inner'));
    });

    test('description as sibling <DD> of <DT>', () {
      final f = BookmarkFileParser.parse(_wrap('''
<DT><A HREF="https://example.com">X</A>
<DD>Some description
'''));
      expect(f.bookmarks.first.description, 'Some description');
    });

    test('duplicate URL within file → only first kept', () {
      final f = BookmarkFileParser.parse(_wrap('''
<DT><A HREF="https://example.com">First</A>
<DT><A HREF="https://example.com">Second</A>
'''));
      expect(f.bookmarks, hasLength(1));
      expect(f.bookmarks.first.title, 'First');
    });

    test('folder <H3> entries are skipped as bookmarks', () {
      final f = BookmarkFileParser.parse(_wrap('''
<DT><H3>Just a folder</H3>
<DL><p>
</DL><p>
'''));
      expect(f.bookmarks, isEmpty);
    });

    test('two flat bookmarks both kept', () {
      final f = BookmarkFileParser.parse(_wrap('''
<DT><A HREF="https://a.com">A</A>
<DT><A HREF="https://b.com">B</A>
'''));
      expect(f.bookmarks, hasLength(2));
      expect(f.bookmarks.map((b) => b.url), ['https://a.com', 'https://b.com']);
    });

    test('anchor with only whitespace text uses href as title', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://example.com">   </A>',
      ));
      expect(f.bookmarks.first.title, 'https://example.com');
    });

    test('ADD_DATE 0 falls back to now', () {
      final before = DateTime.now().toUtc();
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://x.com" ADD_DATE="0">X</A>',
      ));
      final after = DateTime.now().toUtc();
      final b = f.bookmarks.first;
      expect(b.createdAt.isBefore(before), isFalse);
      expect(b.createdAt.isAfter(after), isFalse);
    });

    test('TAGS attribute with mixed case lowercased', () {
      final f = BookmarkFileParser.parse(_wrap(
        '<DT><A HREF="https://x.com" TAGS="News,Tech">X</A>',
      ));
      expect(f.bookmarks.first.tags, ['news', 'tech']);
    });

    test('no <DL> → no bookmarks', () {
      final f = BookmarkFileParser.parse('<p>not a bookmarks file</p>');
      expect(f.bookmarks, isEmpty);
    });
  });
}