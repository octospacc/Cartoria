import 'package:Cartoria/data/models.dart';
import 'package:Cartoria/data/repos/post_repo.dart';
import 'package:flutter_test/flutter_test.dart';

String _postSource({
  String? id,
  String? kind,
  String? created,
  String body = '<p>hi</p>',
}) {
  final fields = <String>[
    if (id != null) '"id": "$id"',
    if (kind != null) '"kind": "$kind"',
    if (created != null) '"created": "$created"',
  ];
  final fm = fields.isEmpty ? '{}' : '{${fields.join(', ')}}';
  return '<!---\n$fm\n--->\n\n$body';
}

void main() {
  group('PostRepository.parseInlinePost', () {
    test('parses a minimal note', () {
      final post = PostRepository.parseInlinePost(_postSource(
        id: 'p1',
        kind: 'note',
        created: '2026-01-15T12:00:00.000Z',
      ));
      expect(post.id, 'p1');
      expect(post.kind, PostKind.note);
      expect(post.createdAt, DateTime.utc(2026, 1, 15, 12));
      expect(post.body, '<p>hi</p>');
    });

    test('parses a bookmark with url', () {
      final post = PostRepository.parseInlinePost(_postSource(
        id: 'p1',
        kind: 'bookmark',
        created: '2026-01-15T12:00:00.000Z',
      ).replaceFirst('{', '{"url":"https://example.com", '));
      expect(post.kind, PostKind.bookmark);
      expect(post.url, 'https://example.com');
    });

    test('generates an id when missing', () {
      final post = PostRepository.parseInlinePost(_postSource(
        kind: 'note',
        created: '2026-01-15T12:00:00.000Z',
      ));
      expect(post.id, isNotEmpty);
      expect(post.id, isNot('inline')); // not the file-based fallback
    });

    test('throws when frontmatter is absent', () {
      expect(
        () => PostRepository.parseInlinePost('<p>just body</p>'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when "created" is missing', () {
      expect(
        () => PostRepository.parseInlinePost(_postSource(kind: 'note')),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when "created" is invalid', () {
      expect(
        () => PostRepository.parseInlinePost(_postSource(
          kind: 'note',
          created: 'not-a-timestamp',
        )),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when "kind" is unknown', () {
      expect(
        () => PostRepository.parseInlinePost(_postSource(
          kind: 'weird',
          created: '2026-01-15T12:00:00.000Z',
        )),
        throwsA(isA<FormatException>()),
      );
    });
  });
}