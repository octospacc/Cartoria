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
  final paraRegex =
      RegExp(r'<p>(.*?)</p>', dotAll: true, caseSensitive: false);
  final paragraphs = paraRegex
      .allMatches(html)
      .map((m) => unescapeHtml(m
          .group(1)!
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')))
      .toList();
  if (paragraphs.isEmpty) {
    return unescapeHtml(html.replaceAll(RegExp(r'<[^>]+>'), '')).trim();
  }
  return paragraphs.join('\n\n');
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