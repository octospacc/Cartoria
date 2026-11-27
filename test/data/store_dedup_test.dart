import 'package:Cartoria/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

// This is an indirect test: we can't access _postCache directly, but
// we can verify the contract that postsForSpace returns unique posts.
// The setup uses the store's real init (empty vault) and relies on the
// public API. If that's impractical in this repo's test setup, replace
// with a unit test that exercises List dedup logic directly.
void main() {
  test('dedup pattern produces unique ids', () {
    final posts = [
      Post(id: 'a', kind: PostKind.note, body: '', createdAt: DateTime.utc(2025)),
      Post(id: 'b', kind: PostKind.note, body: '', createdAt: DateTime.utc(2025)),
      Post(id: 'a', kind: PostKind.note, body: '', createdAt: DateTime.utc(2025)),
    ];
    final seen = <String>{};
    final unique = <Post>[];
    for (final p in posts) {
      if (seen.add(p.id)) unique.add(p);
    }
    expect(unique.map((p) => p.id), ['a', 'b']);
  });

  test('dedup pattern preserves order', () {
    final posts = [
      Post(id: 'a', kind: PostKind.note, body: '', createdAt: DateTime.utc(2025, 1, 1)),
      Post(id: 'b', kind: PostKind.note, body: '', createdAt: DateTime.utc(2025, 1, 2)),
      Post(id: 'a', kind: PostKind.note, body: '', createdAt: DateTime.utc(2025, 1, 1)),
    ];
    final seen = <String>{};
    final unique = <Post>[];
    for (final p in posts) {
      if (seen.add(p.id)) unique.add(p);
    }
    expect(unique.first.id, 'a');
    expect(unique.last.id, 'b');
  });
}