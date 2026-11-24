import 'package:Cartoria/data/models.dart';
import 'package:Cartoria/util/post_serialization.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({
  String id = 'p1',
  PostKind kind = PostKind.note,
  String body = '',
  String? url,
  String? title,
}) =>
    Post(
      id: id,
      kind: kind,
      body: body,
      url: url,
      title: title,
      createdAt: DateTime.utc(2025),
    );

Post _postWithDate({
  String id = 'p1',
  PostKind kind = PostKind.note,
  String body = '',
  String? url,
  String? title,
  required DateTime createdAt,
}) =>
    Post(
      id: id,
      kind: kind,
      body: body,
      url: url,
      title: title,
      createdAt: createdAt,
    );

void main() {
  group('postToPlaintext', () {
    test('empty post → empty string', () {
      expect(postToPlaintext(_post()), '');
    });

    test('body only → body', () {
      expect(postToPlaintext(_post(body: '<p>hello</p>')), 'hello');
    });

    test('url only (no body) → url', () {
      expect(
        postToPlaintext(_post(url: 'https://example.com')),
        'https://example.com',
      );
    });

    test('body and url → both separated by blank line', () {
      expect(
        postToPlaintext(_post(
          body: '<p>check this</p>',
          url: 'https://example.com',
        )),
        'check this\n\nhttps://example.com',
      );
    });

    test('url already in body → not duplicated', () {
      expect(
        postToPlaintext(_post(
          body: '<p>see https://example.com here</p>',
          url: 'https://example.com',
        )),
        'see https://example.com here',
      );
    });

    test('title included for bookmark', () {
      expect(
        postToPlaintext(_post(
          kind: PostKind.bookmark,
          title: 'Example Site',
          url: 'https://example.com',
        )),
        'Example Site\n\nhttps://example.com',
      );
    });

    test('title + body + url all present', () {
      expect(
        postToPlaintext(_post(
          kind: PostKind.bookmark,
          title: 'T',
          body: '<p>B</p>',
          url: 'https://example.com',
        )),
        'T\n\nB\n\nhttps://example.com',
      );
    });
  });

  group('postToHtml', () {
    test('empty post → empty string', () {
      expect(postToHtml(_post()), '');
    });

    test('body only → body verbatim', () {
      expect(
        postToHtml(_post(body: '<p><strong>x</strong></p>')),
        '<p><strong>x</strong></p>',
      );
    });

    test('url only → link paragraph', () {
      final html = postToHtml(_post(url: 'https://example.com'));
      expect(html, contains('<a href="https://example.com"'));
      expect(html, contains('https://example.com</a>'));
    });

    test('body and url → body then link paragraph', () {
      final html = postToHtml(_post(
        body: '<p>check this</p>',
        url: 'https://example.com',
      ));
      expect(html, contains('<p>check this</p>'));
      expect(html, contains('<a href='));
    });

    test('url in body → not duplicated', () {
      final html = postToHtml(_post(
        body: '<p>see https://example.com here</p>',
        url: 'https://example.com',
      ));
      expect('<a href'.allMatches(html).length, 0);
    });

    test('title escaped when it contains HTML', () {
      final html = postToHtml(_post(
        kind: PostKind.bookmark,
        title: 'A < B',
        url: 'https://x.com',
      ));
      expect(html, contains('A &lt; B'));
      expect(html, isNot(contains('A < B')));
    });

    test('URL escaped in href and body', () {
      final html = postToHtml(_post(url: 'https://x.com/?a=1&b=2'));
      expect(html, contains('&amp;'));
    });
  });

  group('postsToPlaintext', () {
    test('empty list → empty string', () {
      expect(postsToPlaintext([]), '');
    });

    test('single post → its plaintext', () {
      expect(
        postsToPlaintext([_post(body: '<p>hello</p>')]),
        'hello',
      );
    });

    test('two posts → separated by ---', () {
      expect(
        postsToPlaintext([
          _post(id: 'p1', body: '<p>first</p>'),
          _post(id: 'p2', body: '<p>second</p>'),
        ]),
        'first\n\n---\n\nsecond',
      );
    });

    test('three posts → all present and ordered', () {
      final result = postsToPlaintext([
        _post(id: 'p1', body: '<p>a</p>'),
        _post(id: 'p2', body: '<p>b</p>'),
        _post(id: 'p3', body: '<p>c</p>'),
      ]);
      final aIdx = result.indexOf('a');
      final bIdx = result.indexOf('b');
      final cIdx = result.indexOf('c');
      expect(aIdx, lessThan(bIdx));
      expect(bIdx, lessThan(cIdx));
    });

    test('empty posts in list are skipped', () {
      expect(
        postsToPlaintext([
          _post(id: 'p1', body: '<p>a</p>'),
          _post(id: 'p2'),
          _post(id: 'p3', body: '<p>c</p>'),
        ]),
        'a\n\n---\n\nc',
      );
    });
  });

  group('postsToHtml', () {
    test('empty list → empty string', () {
      expect(postsToHtml([]), '');
    });

    test('single post → its html', () {
      expect(
        postsToHtml([_post(body: '<p>x</p>')]),
        '<p>x</p>',
      );
    });

    test('two posts → separated by <hr>', () {
      expect(
        postsToHtml([
          _post(id: 'p1', body: '<p>a</p>'),
          _post(id: 'p2', body: '<p>b</p>'),
        ]),
        '<p>a</p>\n<hr>\n<p>b</p>',
      );
    });

    test('empty posts in list are skipped', () {
      expect(
        postsToHtml([
          _post(id: 'p1', body: '<p>a</p>'),
          _post(id: 'p2'),
          _post(id: 'p3', body: '<p>c</p>'),
        ]),
        '<p>a</p>\n<hr>\n<p>c</p>',
      );
    });
  });

  group('formatPostDate', () {
    test('formats local time as YYYY-MM-DD HH:MM', () {
      expect(
        formatPostDate(DateTime(2025, 3, 15, 14, 30)),
        '2025-03-15 14:30',
      );
    });

    test('pads single digits', () {
      expect(
        formatPostDate(DateTime(2025, 1, 5, 9, 5)),
        '2025-01-05 09:05',
      );
    });
  });

  group('postToPlaintextDated', () {
    test('prefixes body with [date]', () {
      final post = _postWithDate(
        body: '<p>hello</p>',
        createdAt: DateTime(2025, 3, 15, 14, 30),
      );
      expect(
        postToPlaintextDated(post),
        '[2025-03-15 14:30]\nhello',
      );
    });

    test('empty post → empty string', () {
      final post = _postWithDate(createdAt: DateTime(2025, 3, 15));
      expect(postToPlaintextDated(post), '');
    });
  });

  group('postsToPlaintextDated', () {
    test('multiple posts separated by ---', () {
      final posts = [
        _postWithDate(
          id: 'p1',
          body: '<p>a</p>',
          createdAt: DateTime(2025, 1, 1, 10),
        ),
        _postWithDate(
          id: 'p2',
          body: '<p>b</p>',
          createdAt: DateTime(2025, 2, 2, 11),
        ),
      ];
      final out = postsToPlaintextDated(posts);
      expect(out, contains('[2025-01-01 10:00]'));
      expect(out, contains('[2025-02-02 11:00]'));
      expect(out, contains('---'));
    });
  });

  group('postToHtmlDated', () {
    test('prefixes body with <small>[date]</small>', () {
      final post = _postWithDate(
        body: '<p>hello</p>',
        createdAt: DateTime(2025, 3, 15, 14, 30),
      );
      final html = postToHtmlDated(post);
      expect(html, contains('<small>[2025-03-15 14:30]</small>'));
      expect(html, contains('<p>hello</p>'));
    });

    test('empty post → empty string', () {
      final post = _postWithDate(createdAt: DateTime(2025));
      expect(postToHtmlDated(post), '');
    });
  });

  group('postsToHtmlDated', () {
    test('multiple posts separated by <hr>', () {
      final posts = [
        _postWithDate(
          id: 'p1',
          body: '<p>a</p>',
          createdAt: DateTime(2025, 1, 1, 10),
        ),
        _postWithDate(
          id: 'p2',
          body: '<p>b</p>',
          createdAt: DateTime(2025, 2, 2, 11),
        ),
      ];
      final out = postsToHtmlDated(posts);
      expect('<hr>'.allMatches(out).length, 1);
      expect(out, contains('[2025-01-01 10:00]'));
      expect(out, contains('[2025-02-02 11:00]'));
    });
  });
}