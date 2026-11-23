import 'package:Cartoria/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({
  String id = 'p1',
  PostKind kind = PostKind.note,
  String body = '',
  String? url,
  List<String> fileIds = const [],
  DateTime? createdAt,
  DateTime? editedAt,
  String? quotedPostId,
  List<QuotedExternal> quotedExternals = const [],
  Map<String, PostHookState> hookState = const {},
}) =>
    Post(
      id: id,
      kind: kind,
      body: body,
      url: url,
      fileIds: fileIds,
      createdAt: createdAt ?? DateTime.utc(2025),
      editedAt: editedAt,
      quotedPostId: quotedPostId,
      quotedExternals: quotedExternals,
      hookState: hookState,
    );

void main() {
  group('Post.plaintext', () {
    test('extracts text from a single paragraph', () {
      expect(_post(body: '<p>hello</p>').plaintext, 'hello');
    });

    test('separates paragraphs with blank line', () {
      expect(
        _post(body: '<p>a</p><p>b</p>').plaintext,
        'a\n\nb',
      );
    });

    test('strips inline formatting', () {
      expect(
        _post(body: '<p><strong>bold</strong> plain</p>').plaintext,
        'bold plain',
      );
    });

    test('empty body → empty plaintext', () {
      expect(_post().plaintext, '');
    });
  });

  group('Post.domain', () {
    test('full URL → host', () {
      expect(
        _post(url: 'https://example.com/path').domain,
        'example.com',
      );
    });

    test('URL with port → host only', () {
      expect(
        _post(url: 'https://example.com:8080/path').domain,
        'example.com',
      );
    });

    test('null url → empty string', () {
      expect(_post().domain, '');
    });

    test('empty url → empty string', () {
      expect(_post(url: '').domain, '');
    });

    test('malformed URL falls back to raw', () {
      // Uri.parse accepts many things but has empty host for
      // strings that don't look like URLs; the fallback returns
      // the original.
      expect(_post(url: 'not a url').domain, 'not a url');
    });
  });

  group('Post.formattedCreatedAt', () {
    test('today → HH:MM format (contains colon, no date)', () {
      final post = _post(createdAt: DateTime.now());
      final formatted = post.formattedCreatedAt;
      expect(formatted, contains(':'));
      expect(formatted, isNot(contains('-')));
    });

    test('past day → YYYY-MM-DD HH:MM (contains dash)', () {
      final post = _post(
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(post.formattedCreatedAt, contains('-'));
      expect(post.formattedCreatedAt, contains(':'));
    });
  });

  group('Post.formattedEditedAt', () {
    test('null when never edited', () {
      expect(_post().formattedEditedAt, isNull);
    });

    test('non-null when edited', () {
      final post = _post(editedAt: DateTime.now());
      expect(post.formattedEditedAt, isNotNull);
      expect(post.formattedEditedAt!, contains(':'));
    });
  });

  group('Post.withHookState', () {
    test('preserves all other fields', () {
      final original = _post(
        id: 'x',
        kind: PostKind.bookmark,
        body: '<p>body</p>',
        url: 'https://example.com',
        fileIds: ['f1'],
        quotedPostId: 'q1',
      );
      final next = original.withHookState({
        'h1': PostHookState(lastFiredAt: DateTime.utc(2025)),
      });
      expect(next.id, 'x');
      expect(next.kind, PostKind.bookmark);
      expect(next.body, '<p>body</p>');
      expect(next.url, 'https://example.com');
      expect(next.fileIds, ['f1']);
      expect(next.quotedPostId, 'q1');
      expect(next.hookState.length, 1);
    });
  });

  group('PostHookState', () {
    test('round-trip with required field only', () {
      final s = PostHookState(lastFiredAt: DateTime.utc(2025, 1, 1));
      final r = PostHookState.fromJson(s.toJson());
      expect(r.lastFiredAt, s.lastFiredAt);
      expect(r.lastStatus, isNull);
      expect(r.lastBody, isNull);
      expect(r.lastError, isNull);
      expect(r.lastHeaders, isEmpty);
    });

    test('round-trip with all fields', () {
      final s = PostHookState(
        lastFiredAt: DateTime.utc(2025, 6, 15, 12),
        lastStatus: 200,
        lastBody: '{"ok": true}',
        lastHeaders: {'Content-Type': 'application/json'},
        lastError: null,
      );
      final r = PostHookState.fromJson(s.toJson());
      expect(r.lastFiredAt, s.lastFiredAt);
      expect(r.lastStatus, 200);
      expect(r.lastBody, '{"ok": true}');
      expect(r.lastHeaders, {'Content-Type': 'application/json'});
    });

    test('round-trip with error', () {
      final s = PostHookState(
        lastFiredAt: DateTime.utc(2025),
        lastError: 'connection refused',
      );
      final r = PostHookState.fromJson(s.toJson());
      expect(r.lastError, 'connection refused');
    });
  });

  group('DriveFile', () {
    test('isMissing true is preserved', () {
      final f = DriveFile(
        id: 'f1',
        name: 'photo.jpg',
        sizeBytes: 1024,
        createdAt: DateTime.utc(2025),
        isMissing: true,
      );
      expect(f.isMissing, isTrue);
    });

    test('isMissing defaults false', () {
      final f = DriveFile(
        id: 'f1',
        name: 'photo.jpg',
        sizeBytes: 1024,
        createdAt: DateTime.utc(2025),
      );
      expect(f.isMissing, isFalse);
    });
  });

  group('QuotedExternal', () {
    test('author + uri + text', () {
      const q = QuotedExternal(
        author: 'someone.bsky.social',
        uri: 'at://did:plc:abc/app.bsky.feed.post/xyz',
        text: 'quoted content',
      );
      expect(q.author, 'someone.bsky.social');
      expect(q.uri, isNotNull);
      expect(q.text, 'quoted content');
    });

    test('text-only', () {
      const q = QuotedExternal(text: 'just text');
      expect(q.author, isNull);
      expect(q.uri, isNull);
      expect(q.text, 'just text');
    });
  });

  group('Space', () {
    test('constructs with all fields', () {
      final s = Space(
        id: 'sp1',
        name: 'Test',
        icon: '📓',
        createdAt: DateTime.utc(2025),
      );
      expect(s.id, 'sp1');
      expect(s.name, 'Test');
      expect(s.icon, '📓');
    });
  });
}