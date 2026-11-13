import 'dart:convert';

String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

String unescapeHtml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

String bodyToHtml(String text) {
  if (text.trim().isEmpty) return '';
  final paragraphs = text.split(RegExp(r'\n\s*\n'));
  return paragraphs.map((para) {
    final lines = para.split('\n').map(escapeHtml).join('<br>');
    return '<p>$lines</p>';
  }).join('\n');
}

String bodyFromHtml(String html) {
  if (html.trim().isEmpty) return '';

  var s = html;

  // Inline line breaks → single newline.
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  // Block-level element boundaries → paragraph breaks. Handles open
  // and close in one pattern. Covers markdown's output (p, h1–h6, li,
  // tr, pre, blockquote) plus defensive extras (div, section, article)
  // for hand-edited HTML.
  s = s.replaceAll(
    RegExp(
      r'</?(p|h[1-6]|li|tr|pre|blockquote|div|section|article)[^>]*>',
      caseSensitive: false,
    ),
    '\n\n',
  );

  // Horizontal rules become an em-dash line so they survive an edit.
  s = s.replaceAll(
    RegExp(r'<hr\s*/?>', caseSensitive: false),
    '\n\n—\n\n',
  );

  // Strip any remaining tags (inline: strong, em, code, a, img, …).
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = unescapeHtml(s);

  // Normalise whitespace.
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

Map<String, dynamic> parseFrontmatterMeta(String content) {
  if (!content.startsWith('<!---')) return {};
  final end = content.indexOf('--->', 4);
  if (end < 0) throw const FormatException('Unclosed frontmatter');
  final raw = content.substring(5, end).trim();
  if (raw.isEmpty) return {};
  return (jsonDecode(raw) as Map).cast<String, dynamic>();
}

String bodyAfterFrontmatter(String content) {
  if (!content.startsWith('<!---')) return content;
  final end = content.indexOf('--->', 4);
  if (end < 0) return content;
  return content.substring(end + 4).trimLeft();
}

String makeDocument(Map<String, dynamic> meta, String body) {
  const encoder = JsonEncoder.withIndent('  ');
  return '<!---\n${encoder.convert(meta)}\n--->\n\n$body';
}