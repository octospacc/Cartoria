import '../bookmarks.dart';
import '../models.dart';
import 'post_repo.dart';

class BookmarkImportResult {
  final int total;
  final int added;
  final int skippedDuplicates;
  final int skippedInvalid;

  const BookmarkImportResult({
    required this.total,
    required this.added,
    required this.skippedDuplicates,
    required this.skippedInvalid,
  });
}

/// Writes parsed bookmarks into a space via [PostRepository].
///
/// Stateless and does **not** call `notifyListeners()` — the [VaultStore]
/// facade owns the cache and the notification. Returns the full list of
/// created posts alongside the summary so the facade can update its cache
/// in one shot rather than per-post.
class BookmarksImporter {
  final PostRepository posts;

  const BookmarksImporter({required this.posts});

  Future<({BookmarkImportResult result, List<Post> created})> importInto({
    required String spaceId,
    required List<ImportedBookmark> bookmarks,
    required Set<String> existingUrls,
  }) async {
    final seen = {...existingUrls};
    final created = <Post>[];
    var skippedDuplicates = 0;
    var skippedInvalid = 0;

    for (final b in bookmarks) {
      final uri = Uri.tryParse(b.url);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        skippedInvalid++;
        continue;
      }
      if (!seen.add(b.url)) {
        skippedDuplicates++;
        continue;
      }
      try {
        created.add(await posts.create(
          spaceId: spaceId,
          kind: PostKind.bookmark,
          plaintextBody: '',
          url: b.url,
          title: b.title,
          description: b.description,
          thumbnail: b.thumbnail,
          tags: b.tags,
          fileIds: const [],
          createdAt: b.createdAt,
        ));
      } catch (e) {
        skippedInvalid++;
      }
    }

    return (
      result: BookmarkImportResult(
        total: bookmarks.length,
        added: created.length,
        skippedDuplicates: skippedDuplicates,
        skippedInvalid: skippedInvalid,
      ),
      created: created,
    );
  }
}