import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// One bookmark extracted from a Netscape-format HTML file.
class ImportedBookmark {
  final String url;
  final String title;
  final String? description;
  final String? thumbnail;
  final List<String> tags;
  final DateTime createdAt;

  const ImportedBookmark({
    required this.url,
    required this.title,
    this.description,
    this.thumbnail,
    this.tags = const [],
    required this.createdAt,
  });
}

class BookmarkFile {
  /// Best guess at a human-readable name for the file, from `<TITLE>` or
  /// `<H1>`. Null if neither is present.
  final String? title;
  final List<ImportedBookmark> bookmarks;

  const BookmarkFile({this.title, required this.bookmarks});
}

/// Parses the Netscape "Bookmarks" HTML export format, as produced by
/// Firefox, Chrome, Safari, Raindrop.io, and most other managers.
///
/// The source format is malformed HTML by design: `<DT>` / `<DD>` are
/// never closed, and `<DL><p>` opens a `<p>` that is never closed. The
/// HTML5 parsing algorithm in `package:html` handles most of this, but
/// **does not** auto-close a `<DT>` when a sibling `<DT>` begins — so a
/// flat sibling list in the source becomes a nested `<DT>` chain in the
/// DOM. This parser therefore does not rely on sibling relationships for
/// traversal: it enumerates every `<dt>` descendant and reconstructs the
/// folder chain by walking ancestors.
///
/// Folder names become tags on the contained bookmarks. Attribute names
/// are lowercased by the parser; the source usually writes them uppercase
/// (`ADD_DATE`, `TAGS`, `DATA-COVER`).
class BookmarkFileParser {
  static BookmarkFile parse(String source) {
    final doc = html_parser.parse(source);
    final title = _nonEmpty(doc.querySelector('title')?.text) ??
        _nonEmpty(doc.querySelector('h1')?.text);
    final results = <ImportedBookmark>[];
    final root = doc.querySelector('dl');
    if (root != null) _collect(root, results);
    return BookmarkFile(title: title, bookmarks: results);
  }

  static void _collect(Element rootDl, List<ImportedBookmark> out) {
    final seenUrls = <String>{};
    for (final dt in rootDl.querySelectorAll('dt')) {
      // Folder headers always contain an <h3>. Skip them; their nested
      // <dt> descendants are still visited by this same loop.
      if (dt.querySelector('h3') != null) continue;

      final a = dt.querySelector('a');
      if (a == null) continue;

      final href = a.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;

      // Dedupe within the file: the same URL saved into two folders is
      // imported once, keeping the first occurrence's folder context.
      if (!seenUrls.add(href)) continue;

      final folders = _foldersFor(a, rootDl);
      final description = _descriptionFor(a, dt);
      out.add(_toBookmark(a, href, description, folders));
    }
  }

  /// Walks up from [a] to [rootDl], collecting folder names. A folder is
  /// identified by an `<h3>` that either:
  ///   - is a child of a `<dt>` immediately preceding a `<dl>`, or
  ///   - is a direct sibling of a `<dl>` (when `<dt>` auto-close failed
  ///     and `<h3>` ended up as a sibling of the nested `<dl>`).
  static List<String> _foldersFor(Element a, Element rootDl) {
    final folders = <String>[];
    Element? cursor = a.parent;
    while (cursor != null && cursor != rootDl) {
      if (cursor.localName == 'dl') {
        var prev = cursor.previousElementSibling;
        while (prev != null) {
          if (prev.localName == 'dt') {
            final h3 = prev.querySelector('h3');
            if (h3 != null) {
              final name = h3.text.trim();
              if (name.isNotEmpty) folders.insert(0, name);
            }
            break;
          }
          if (prev.localName == 'h3') {
            final name = prev.text.trim();
            if (name.isNotEmpty) folders.insert(0, name);
            break;
          }
          prev = prev.previousElementSibling;
        }
      }
      cursor = cursor.parent;
    }
    return folders;
  }

  /// Best-effort description extraction. In well-formed files the `<dd>`
  /// immediately follows the `<dt>` as a sibling; in broken ones it may
  /// end up as a sibling of the `<a>` or nested inside the `<dt>`.
  static String? _descriptionFor(Element a, Element dt) {
    if (dt.nextElementSibling?.localName == 'dd') {
      return _nonEmpty(dt.nextElementSibling!.text);
    }
    if (a.nextElementSibling?.localName == 'dd') {
      return _nonEmpty(a.nextElementSibling!.text);
    }
    final nestedDd = dt.querySelector('dd');
    if (nestedDd != null) return _nonEmpty(nestedDd.text);
    return null;
  }

  static ImportedBookmark _toBookmark(
    Element a,
    String href,
    String? description,
    List<String> folders,
  ) {
    final tags = <String>[];
    for (final raw in (a.attributes['tags'] ?? '').split(',')) {
      final t = raw.trim().toLowerCase();
      if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
    }
    for (final folder in folders) {
      final t = folder.trim().toLowerCase();
      if (t.isNotEmpty && !tags.contains(t)) tags.add(t);
    }

    final addDate = int.tryParse(a.attributes['add_date'] ?? '');
    final createdAt = addDate != null && addDate > 0
        ? DateTime.fromMillisecondsSinceEpoch(addDate * 1000, isUtc: true)
        : DateTime.now().toUtc();

    return ImportedBookmark(
      url: href,
      title: _nonEmpty(a.text) ?? href,
      description: description,
      thumbnail: _nonEmpty(a.attributes['data-cover']),
      tags: tags,
      createdAt: createdAt,
    );
  }

  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}