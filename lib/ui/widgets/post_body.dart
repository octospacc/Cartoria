import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// One segment of a parsed post body: either plain text or a link.
class _BodyRun {
  final String text;
  final String? href;
  const _BodyRun.text(this.text) : href = null;
  const _BodyRun.link(this.text, this.href);
  bool get isLink => href != null;
}

/// Parses post body HTML into a flat sequence of text / link runs.
///
/// Handles:
///   * `<a href="X">Y</a>` → link run with display Y
///   * `<br>` → newline
///   * `<p>…</p>` → paragraph breaks
///   * bare URLs in non-link text → link runs (href == display)
///
/// Non-link text is HTML-unescaped. Link display and href values are also
/// unescaped. Trailing punctuation on bare URLs (`.`, `,`, `;`, unmatched
/// closing brackets) is stripped from the URL and re-emitted as text, so
/// "see https://example.com." links `https://example.com` and leaves the
/// period outside.
List<_BodyRun> _parseBodyRuns(String html) {
  if (html.trim().isEmpty) return const [];

  var s = html;

  // Normalize paragraph boundaries to exactly one blank line ("\n\n").
  // The on-disk format emits "<p>…</p>\n<p>…</p>", so blindly replacing
  // "</p>" with "\n\n" leaves the input's own "\n" in place and produces
  // three newlines per boundary. Extracting each <p>'s inner content and
  // re-joining with a single separator ignores whatever whitespace sits
  // between tags, so the gap is always exactly two newlines.
  final pRe =
      RegExp(r'<p[^>]*>(.*?)</p\s*>', caseSensitive: false, dotAll: true);
  final paragraphMatches = pRe.allMatches(s).toList();
  if (paragraphMatches.isNotEmpty) {
    final sb = StringBuffer();
    for (var i = 0; i < paragraphMatches.length; i++) {
      if (i > 0) sb.write('\n\n');
      sb.write(paragraphMatches[i].group(1)!);
    }
    s = sb.toString();
  }

  // Inside-paragraph line breaks (from `<br>` in the source or the script's
  // multi-line facet rendering).
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  final runs = <_BodyRun>[];
  final anchorRe = RegExp(
    r'<a\s+[^>]*href="([^"]*)"[^>]*>(.*?)</a\s*>',
    caseSensitive: false,
    dotAll: true,
  );

  var cursor = 0;
  for (final m in anchorRe.allMatches(s)) {
    if (m.start > cursor) {
      _emitText(s.substring(cursor, m.start), runs);
    }
    final href = _unescape(m.group(1)!);
    var display = _unescape(m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), ''));
    if (display.isEmpty) display = href;
    runs.add(_BodyRun.link(display, href));
    cursor = m.end;
  }
  if (cursor < s.length) {
    _emitText(s.substring(cursor), runs);
  }

  // Trim leading/trailing whitespace on the boundary runs only.
  while (
      runs.isNotEmpty && !runs.first.isLink && runs.first.text.trim().isEmpty) {
    runs.removeAt(0);
  }
  while (
      runs.isNotEmpty && !runs.last.isLink && runs.last.text.trim().isEmpty) {
    runs.removeLast();
  }
  if (runs.isNotEmpty && !runs.first.isLink) {
    runs[0] = _BodyRun.text(runs[0].text.trimLeft());
  }
  if (runs.isNotEmpty && !runs.last.isLink) {
    runs[runs.length - 1] =
        _BodyRun.text(runs[runs.length - 1].text.trimRight());
  }
  return runs;
}

final _urlRe = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

void _emitText(String raw, List<_BodyRun> out) {
  final text = _unescape(raw);
  var cursor = 0;
  for (final m in _urlRe.allMatches(text)) {
    if (m.start > cursor) {
      out.add(_BodyRun.text(text.substring(cursor, m.start)));
    }
    final (url, trailing) = _splitTrailing(m.group(0)!);
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      out.add(_BodyRun.link(url, url));
      if (trailing.isNotEmpty) out.add(_BodyRun.text(trailing));
    } else {
      out.add(_BodyRun.text(m.group(0)!));
    }
    cursor = m.end;
  }
  if (cursor < text.length) {
    out.add(_BodyRun.text(text.substring(cursor)));
  }
}

/// Splits trailing punctuation off [raw], returning (url, trailing).
///
/// `.,;:!?` and quotes are always stripped. Closing brackets `)]}` are
/// stripped only when unbalanced — `https://example.com/a_(b)` keeps its
/// balanced `)`, while `(see https://example.com/a)` strips the unmatched
/// outer `)`.
(String, String) _splitTrailing(String raw) {
  var url = raw;
  var trailing = '';
  while (url.isNotEmpty) {
    final last = url[url.length - 1];
    final shouldStrip = '.,;:!?\'"'.contains(last) ||
        (last == ')' && !_balanced(url, '(', ')')) ||
        (last == ']' && !_balanced(url, '[', ']')) ||
        (last == '}' && !_balanced(url, '{', '}'));
    if (!shouldStrip) break;
    trailing = last + trailing;
    url = url.substring(0, url.length - 1);
  }
  return (url, trailing);
}

bool _balanced(String s, String open, String close) {
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    if (s[i] == open) depth++;
    if (s[i] == close) depth--;
  }
  return depth == 0;
}

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

/// Renders a post body with inline clickable links.
///
/// Reads from [html] (the post's on-disk body) rather than plaintext, so
/// `<a href>` markup is preserved. Bare URLs in text are also made
/// clickable. Works inside the feed's existing [SelectionArea] — drag
/// selects, tap on a link opens it.
class PostBodyText extends StatefulWidget {
  final String html;
  final TextStyle? style;

  const PostBodyText({
    super.key,
    required this.html,
    this.style,
  });

  @override
  State<PostBodyText> createState() => _PostBodyTextState();
}

class _PostBodyTextState extends State<PostBodyText> {
  // Cache the parsed runs so a parent rebuild doesn't re-scan the HTML.
  List<_BodyRun>? _cachedRuns;
  String? _cachedHtml;

  // Recognizers are recreated on every build (cheap) but must be disposed
  // to avoid leaks. The list is replaced wholesale each build.
  List<TapGestureRecognizer> _recognizers = const [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers = const [];
  }

  List<_BodyRun> _runs() {
    if (_cachedHtml == widget.html && _cachedRuns != null) {
      return _cachedRuns!;
    }
    _cachedHtml = widget.html;
    _cachedRuns = _parseBodyRuns(widget.html);
    return _cachedRuns!;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final theme = Theme.of(context);
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;
    final linkStyle = (baseStyle ?? const TextStyle()).copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    final runs = _runs();
    final spans = <InlineSpan>[];
    final newRecognizers = <TapGestureRecognizer>[];

    for (final run in runs) {
      if (run.isLink) {
        final rec = TapGestureRecognizer()
          ..onTap = () => _openUrl(context, run.href!);
        newRecognizers.add(rec);
        spans.add(TextSpan(
          text: run.text,
          style: linkStyle,
          recognizer: rec,
        ));
      } else {
        spans.add(TextSpan(text: run.text, style: baseStyle));
      }
    }
    _recognizers = newRecognizers;

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }
}
