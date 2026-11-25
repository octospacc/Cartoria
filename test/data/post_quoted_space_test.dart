import 'package:Cartoria/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post.quotedSpaceId', () {
    test('defaults to null', () {
      final post = Post(
        id: 'p',
        kind: PostKind.note,
        body: '',
        createdAt: DateTime(2025),
      );
      expect(post.quotedSpaceId, isNull);
    });

    test('can be set alongside quotedPostId', () {
      final post = Post(
        id: 'p',
        kind: PostKind.note,
        body: '',
        createdAt: DateTime(2025),
        quotedPostId: 'q',
        quotedSpaceId: 'other-space',
      );
      expect(post.quotedPostId, 'q');
      expect(post.quotedSpaceId, 'other-space');
    });

    test('withHookState preserves quotedSpaceId', () {
      final post = Post(
        id: 'p',
        kind: PostKind.note,
        body: '',
        createdAt: DateTime(2025),
        quotedPostId: 'q',
        quotedSpaceId: 'other-space',
      );
      final next = post.withHookState({});
      expect(next.quotedPostId, 'q');
      expect(next.quotedSpaceId, 'other-space');
    });
  });
}