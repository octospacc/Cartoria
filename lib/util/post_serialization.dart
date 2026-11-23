import '../data/models.dart';
import 'html_utils.dart';

/// Builds the plaintext representation of [post] for clipboard use.
///
/// Unlike `Post.plaintext` (which only extracts the body), this method
/// also includes the title and URL for bookmarks. That preserves the
/// information a user expects when pasting the copied content into a
/// plain text destination (email draft, chat, text file, etc.).
///
/// The URL is skipped when it already appears in the body — pasted
/// posts whose body already shows the URL don't get it appended twice.
String postToPlaintext(Post post) {
  final buf = StringBuffer();
  if (post.title != null && post.title!.isNotEmpty) {
    buf.write(post.title);
  }
  final body = post.plaintext;
  if (body.isNotEmpty) {
    if (buf.isNotEmpty) buf.write('\n\n');
    buf.write(body);
  }
  final url = post.url;
  if (url != null && url.isNotEmpty && !body.contains(url)) {
    if (buf.isNotEmpty) buf.write('\n\n');
    buf.write(url);
  }
  return buf.toString();
}

/// Builds the HTML representation of [post] for rich clipboard use.
///
/// Preserves the post body verbatim — that's where any formatting the
/// post carries lives. Title and URL are added as additional
/// paragraphs so their content survives the paste; the URL becomes a
/// clickable anchor for destinations that render HTML.
String postToHtml(Post post) {
  final buf = StringBuffer();
  if (post.title != null && post.title!.isNotEmpty) {
    buf.write('<p>${escapeHtml(post.title!)}</p>');
  }
  final body = post.body;
  if (body.isNotEmpty) {
    if (buf.isNotEmpty) buf.write('\n');
    buf.write(body);
  }
  final url = post.url;
  if (url != null && url.isNotEmpty && !body.contains(url)) {
    if (buf.isNotEmpty) buf.write('\n');
    final escUrl = escapeHtml(url);
    buf.write('<p><a href="$escUrl">$escUrl</a></p>');
  }
  return buf.toString();
}

/// Concatenates [posts] in input order, separated by `---` lines (the
/// same divider used in the app between post cards). Empty results
/// (posts with no content) are skipped.
String postsToPlaintext(List<Post> posts) {
  return posts
      .map(postToPlaintext)
      .where((s) => s.isNotEmpty)
      .join('\n\n---\n\n');
}

/// Concatenates [posts] in input order, separated by `<hr>` tags. The
/// `<hr>` is semantically and visually the same divider the plaintext
/// path uses, so pasting into an HTML destination produces the same
/// structure.
String postsToHtml(List<Post> posts) {
  return posts.map(postToHtml).where((s) => s.isNotEmpty).join('\n<hr>\n');
}