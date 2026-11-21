import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/html_image_cache.dart';
import '../../l10n/l10n.dart';

/// Renders a post body with full HTML support.
///
/// Blocks: `<p>`, `<h1>`–`<h6>`, `<ul>`, `<ol>`, `<pre>`, `<blockquote>`,
/// `<hr>`, `<img>`, `<table>`. Anything else falls through to a
/// paragraph containing its inline contents, so no text is lost.
///
/// Inline: `<strong>`/`<b>`, `<em>`/`<i>`, `<u>`, `<del>`/`<s>`,
/// `<code>`, `<a href>`, `<br>`, `<img>` (small placeholder).
/// Bare URLs in text are auto-linked.
///
/// Works inside a parent `SelectionArea` — text selects, tap on a link
/// opens it. `TapGestureRecognizer`s are tracked and disposed with the
/// widget or on cache invalidation, so no leak.
class PostBodyText extends StatefulWidget {
  final String html;
  final TextStyle? style;
  final HtmlImageCache? imageCache;

  const PostBodyText({
    super.key,
    required this.html,
    this.style,
    this.imageCache,
  });

  @override
  State<PostBodyText> createState() => _PostBodyTextState();
}

class _PostBodyTextState extends State<PostBodyText> {
  List<Widget>? _blocks;
  String? _cachedHtml;
  Brightness? _cachedBrightness;
  List<TapGestureRecognizer> _recognizers = [];

  static final _urlRe = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers = [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_cachedHtml != widget.html || _cachedBrightness != theme.brightness) {
      _disposeRecognizers();
      _imageFutures.clear();
      _cachedHtml = widget.html;
      _cachedBrightness = theme.brightness;
      _blocks = _buildBlocks(theme);
    }
    if (_blocks == null || _blocks!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: _blocks!,
    );
  }

  // ── Block-level rendering ─────────────────────────────────────────────

  List<Widget> _buildBlocks(ThemeData theme) {
    if (widget.html.trim().isEmpty) return const [];
    final doc = html_parser.parse(widget.html);
    final body = doc.body;
    if (body == null) return const [];
    final out = <Widget>[];
    var previousWasTextParagraph = false;
    for (final node in body.nodes) {
      // A `<p>` is a "text paragraph" unless it's just wrapping a single
      // image (in which case `_renderBlock` emits a standalone image and
      // normal image spacing applies).
      final isTextParagraph = node is dom.Element &&
          node.localName == 'p' &&
          _singleImageChild(node) == null;
      final rendered = _renderBlock(node, theme);
      if (rendered.isEmpty) continue;
      if (isTextParagraph && previousWasTextParagraph) {
        // Restore the blank-line spacing that the plaintext renderer
        // produced via `\n\n`, which the HTML renderer lost. Paragraphs
        // already contribute `bottom: 6`, so top up with the remainder
        // of one line height.
        out.add(SizedBox(height: _paragraphTopUp(theme)));
      }
      out.addAll(rendered);
      previousWasTextParagraph = isTextParagraph;
    }
    return out;
  }

  /// Extra vertical space to insert between consecutive text paragraphs
  /// so the visual gap equals one blank line — the spacing the pre-HTML
  /// plaintext renderer produced by emitting `\n\n` as an actual empty
  /// line.
  ///
  /// Reads the effective style (the one [PostBodyText] was given, which
  /// [PostCard] sets to `bodyMedium.copyWith(height: 1.4)`). Falls back
  /// to `14 × 1.4 = 19.6` if the caller doesn't specify either.
  double _paragraphTopUp(ThemeData theme) {
    final style = widget.style ?? theme.textTheme.bodyMedium;
    final fontSize = style?.fontSize ?? 14.0;
    final height = style?.height ?? 1.4;
    final extra = (fontSize * height) - 6.0;
    return extra > 0 ? extra : 10.0;
  }

  List<Widget> _renderBlock(dom.Node node, ThemeData theme) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.trim().isEmpty) return const [];
      return [_paragraph(_inlineSpanFor(node, theme), theme)];
    }
    if (node is! dom.Element) return const [];

    switch (node.localName) {
      case 'p':
        final single = _singleImageChild(node);
        if (single != null) return [_standaloneImage(single, theme)];
        return [_paragraph(_inlineSpans(node, theme), theme)];
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return [_heading(node, theme)];
      case 'ul':
        return [_list(node, theme, ordered: false)];
      case 'ol':
        return [_list(node, theme, ordered: true)];
      case 'pre':
        return [_codeBlock(node, theme)];
      case 'blockquote':
        return [_blockquote(node, theme)];
      case 'hr':
        return [_horizontalRule(theme)];
      case 'img':
        return [_standaloneImage(node, theme)];
      case 'table':
        return [_table(node, theme)];
      case 'br':
        return const [];
      default:
        final spans = _inlineSpans(node, theme);
        if (spans.isEmpty) return const [];
        return [_paragraph(spans, theme)];
    }
  }

  Widget _paragraph(List<InlineSpan> spans, ThemeData theme) {
    if (spans.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: spans),
        style: widget.style,
      ),
    );
  }

  Widget _heading(dom.Element h, ThemeData theme) {
    final level = int.tryParse(h.localName!.substring(1)) ?? 1;
    final fontSize = switch (level) {
      1 => 22.0,
      2 => 19.0,
      3 => 17.0,
      4 => 15.0,
      5 => 14.0,
      _ => 13.0,
    };
    final weight = level <= 2 ? FontWeight.w700 : FontWeight.w600;
    final style = (widget.style ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      fontWeight: weight,
      height: 1.3,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text.rich(
        TextSpan(children: _inlineSpans(h, theme, baseStyle: style)),
        style: style,
      ),
    );
  }

  Widget _list(dom.Element node, ThemeData theme, {required bool ordered}) {
    final items = node.children.where((e) => e.localName == 'li').toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _listItem(items[i], theme, ordered: ordered, index: i),
        ],
      ),
    );
  }

  Widget _listItem(
    dom.Element li,
    ThemeData theme, {
    required bool ordered,
    required int index,
  }) {
    // CommonMark emits one of two shapes for a list item:
    //   tight:  <li>inline content<ul>nested</ul></li>
    //   loose:  <li><p>inline content</p><ul>nested</ul></li>
    // In both cases the FIRST chunk of content goes on the bullet line;
    // any subsequent block nodes render indented below, recursively
    // (handles arbitrary nesting depth).
    //
    // Leading whitespace-only text nodes (the newlines the parser emits
    // between tags) are skipped when locating the first meaningful child.
    final children = li.nodes.toList();
    var start = 0;
    while (start < children.length) {
      final c = children[start];
      if (c is dom.Text && c.text.trim().isEmpty) {
        start++;
      } else {
        break;
      }
    }

    final inlineSpans = <InlineSpan>[];
    final blockNodes = <dom.Node>[];

    if (start < children.length &&
        children[start] is dom.Element &&
        (children[start] as dom.Element).localName == 'p') {
      // Loose list: pull the first <p>'s contents onto the bullet line.
      final firstP = children[start] as dom.Element;
      for (final n in firstP.nodes) {
        inlineSpans.addAll(_inlineSpanFor(n, theme));
      }
      for (var j = start + 1; j < children.length; j++) {
        blockNodes.add(children[j]);
      }
    } else {
      // Tight list: inline content up to the first block element.
      const blockTags = {
        'ul',
        'ol',
        'p',
        'pre',
        'blockquote',
        'table',
        'hr',
        'div',
      };
      var j = start;
      while (j < children.length) {
        final c = children[j];
        if (c is dom.Element && blockTags.contains(c.localName)) break;
        inlineSpans.addAll(_inlineSpanFor(c, theme));
        j++;
      }
      for (; j < children.length; j++) {
        blockNodes.add(children[j]);
      }
    }

    // Trailing whitespace between the inline content and the first block
    // renders as a stray blank line otherwise. Only trim when there's a
    // block below, since trailing whitespace on a leaf item is harmless.
    if (blockNodes.isNotEmpty && inlineSpans.isNotEmpty) {
      final last = inlineSpans.last;
      if (last is TextSpan && last.text != null) {
        final trimmed = last.text!.trimRight();
        if (trimmed != last.text) {
          if (trimmed.isEmpty) {
            inlineSpans.removeLast();
          } else {
            inlineSpans[inlineSpans.length - 1] = TextSpan(
              text: trimmed,
              style: last.style,
              recognizer: last.recognizer,
            );
          }
        }
      }
    }

    final bulletText = ordered ? '${index + 1}.' : '•';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(bulletText, style: widget.style),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: inlineSpans),
                  style: widget.style,
                ),
              ),
            ],
          ),
          if (blockNodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final n in blockNodes) ..._renderBlock(n, theme),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _codeBlock(dom.Element pre, ThemeData theme) {
    final code = pre.querySelector('code') ?? pre;
    final source = code.text.trimRight();
    final language = _codeLanguage(pre);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: language == null
                ? Text(
                    source,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  )
                : HighlightView(
                    source,
                    language: language,
                    // Strip the highlight theme's background and set the
                    // foreground from the app's palette: the syntax colours
                    // come from the theme, the container and text colour
                    // from the app. Keeps light/dark consistent with the
                    // rest of the post body.
                    theme: _codeTheme(theme, source, language),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Extracts the language identifier from a fenced code block.
  ///
  /// Markdown-It and most CommonMark renderers emit
  /// `<pre><code class="language-dart">` for ``` ```dart ``` fences.
  /// Some pipelines emit `lang-dart` or put the class on the `<pre>`.
  /// Handles all three; returns null when the fence had no info string.
  String? _codeLanguage(dom.Element pre) {
    final code = pre.querySelector('code');
    final cls = '${code?.attributes['class'] ?? ''} ${pre.attributes['class'] ?? ''}';
    final m = RegExp(r'(?:language|lang)-([A-Za-z0-9_+#-]+)').firstMatch(cls);
    return m?.group(1)?.toLowerCase();
  }

  /// Builds a highlight.js theme map with the root entry adapted to the
  /// app's light/dark mode. Syntax colouring comes from Atom One Light /
  /// Dark; only the background (transparent, our Container supplies it)
  /// and the default foreground (from `colorScheme.onSurface`) are
  /// overridden.
  Map<String, TextStyle> _codeTheme(
    ThemeData theme,
    String source,
    String language,
  ) {
    final base = theme.brightness == Brightness.dark
        ? atomOneDarkTheme
        : atomOneLightTheme;
    final foreground = theme.colorScheme.onSurface;
    return {
      ...base,
      'root': (base['root'] ?? const TextStyle()).copyWith(
        backgroundColor: Colors.transparent,
        color: foreground,
      ),
    };
  }

  Widget _blockquote(dom.Element bq, ThemeData theme) {
    final children = <Widget>[];
    for (final node in bq.nodes) {
      children.addAll(_renderBlock(node, theme));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 3,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _horizontalRule(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: theme.colorScheme.outlineVariant,
      ),
    );
  }

  dom.Element? _singleImageChild(dom.Element p) {
    final meaningful = <dom.Node>[];
    for (final n in p.nodes) {
      if (n is dom.Text) {
        if (n.text.trim().isEmpty) continue;
        return null;
      }
      meaningful.add(n);
    }
    if (meaningful.length != 1) return null;
    final first = meaningful.first;
    if (first is dom.Element && first.localName == 'img') return first;
    return null;
  }

  Widget _standaloneImage(dom.Element img, ThemeData theme) {
    final src = img.attributes['src'] ?? '';
    final alt = img.attributes['alt'] ?? '';
    if (src.isEmpty) return _imagePlaceholder(alt, theme, context.l10n);

    // Data URI: inline bytes, no network.
    if (src.startsWith('data:')) {
      return _buildDataUriImage(src, alt, theme);
    }

    // SVG by extension. Query strings are tolerated ("x.svg?v=1").
    if (_isSvgUrl(src)) {
      return _buildSvgNetworkImage(src, alt, theme);
    }

    // Raster fallback. Covers PNG, JPEG, GIF, WebP, BMP — whatever the
    // platform's image codec supports.
    return _buildRasterImage(src, alt, theme);
  }

  bool _isSvgUrl(String src) {
    final uri = Uri.tryParse(src);
    if (uri == null) return false;
    return uri.path.toLowerCase().endsWith('.svg');
  }

  Widget _buildRasterImage(String src, String alt, ThemeData theme) {
    return _HtmlImage(
      url: src,
      alt: alt,
      isSvg: false,
      theme: theme,
      cache: widget.imageCache,
      fallbackToNetwork: widget.imageCache == null,
    );
  }

  Widget _buildSvgNetworkImage(String src, String alt, ThemeData theme) {
    return _HtmlImage(
      url: src,
      alt: alt,
      isSvg: true,
      theme: theme,
      cache: widget.imageCache,
      fallbackToNetwork: false,
    );
  }

// ── Data URIs ──────────────────────────────────────────────────────────

  Widget _buildDataUriImage(String src, String alt, ThemeData theme) {
    // Shape: `data:<mime>[;base64],<payload>`
    //   - base64 payload: `iVBORw0…`
    //   - URL-encoded payload (rare): `%3Csvg%3E…`
    final commaIdx = src.indexOf(',');
    if (commaIdx < 0) return _imageErrorBox(alt, theme, context.l10n);

    final header = src.substring('data:'.length, commaIdx);
    final payload = src.substring(commaIdx + 1);
    final isBase64 = header.endsWith(';base64');
    final mimeType =
        (isBase64 ? header.substring(0, header.length - 7) : header)
            .toLowerCase();

    Uint8List bytes;
    try {
      bytes = isBase64
          ? base64Decode(payload)
          : Uint8List.fromList(Uri.decodeFull(payload).codeUnits);
    } catch (_) {
      return _imageErrorBox(alt, theme, context.l10n);
    }

    if (mimeType.startsWith('image/svg')) {
      if (!_looksLikeSvg(bytes)) return _imageErrorBox(alt, theme, context.l10n);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SvgPicture.memory(
            bytes,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => _imageLoadingBox(theme),
          ),
        ),
      );
    }

    // Raster data URI: PNG, JPEG, GIF, WebP.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                _imageErrorBox(alt, theme, context.l10n),
          ),
        ),
      ),
    );
  }

  Widget _table(dom.Element table, ThemeData theme) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0
                  ? BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                    )
                  : null,
              children: [
                for (final cell in rows[r]
                    .children
                    .where((e) => e.localName == 'td' || e.localName == 'th'))
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text.rich(
                      TextSpan(children: _inlineSpans(cell, theme)),
                      style: widget.style?.copyWith(
                        fontWeight: r == 0 ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Inline rendering ──────────────────────────────────────────────────

  List<InlineSpan> _inlineSpans(
    dom.Element parent,
    ThemeData theme, {
    TextStyle? baseStyle,
  }) {
    final spans = <InlineSpan>[];
    for (final child in parent.nodes) {
      spans.addAll(_inlineSpanFor(child, theme, baseStyle: baseStyle));
    }
    return spans;
  }

  List<InlineSpan> _inlineSpanFor(
    dom.Node node,
    ThemeData theme, {
    TextStyle? baseStyle,
  }) {
    if (node is dom.Text) {
      return _linkifyText(node.text, theme, baseStyle);
    }
    if (node is! dom.Element) return const [];

    switch (node.localName) {
      case 'br':
        return const [TextSpan(text: '\n')];
      case 'strong':
      case 'b':
        return _inlineSpans(
          node,
          theme,
          baseStyle: (baseStyle ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold),
        );
      case 'em':
      case 'i':
        return _inlineSpans(
          node,
          theme,
          baseStyle: (baseStyle ?? const TextStyle())
              .copyWith(fontStyle: FontStyle.italic),
        );
      case 'u':
        final base = baseStyle ?? const TextStyle();
        final combined = TextDecoration.combine([
          base.decoration ?? TextDecoration.none,
          TextDecoration.underline,
        ]);
        return _inlineSpans(
          node,
          theme,
          baseStyle: base.copyWith(decoration: combined),
        );
      case 'del':
      case 's':
        final base = baseStyle ?? const TextStyle();
        final combined = TextDecoration.combine([
          base.decoration ?? TextDecoration.none,
          TextDecoration.lineThrough,
        ]);
        return _inlineSpans(
          node,
          theme,
          baseStyle: base.copyWith(decoration: combined),
        );
      case 'code':
        return [
          TextSpan(
            text: node.text,
            style: (baseStyle ?? const TextStyle()).copyWith(
              fontFamily: 'monospace',
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              fontSize: 13,
            ),
          ),
        ];
      case 'a':
        final href = node.attributes['href'];
        final childSpans = _inlineSpans(node, theme, baseStyle: baseStyle);
        if (href == null || href.isEmpty) return childSpans;
        final rec = TapGestureRecognizer()..onTap = () => _openUrl(href);
        _recognizers.add(rec);
        return childSpans.map((s) {
          if (s is TextSpan) {
            final spanBase = s.style ?? baseStyle ?? const TextStyle();
            final combined = TextDecoration.combine([
              spanBase.decoration ?? TextDecoration.none,
              TextDecoration.underline,
            ]);
            final effective = spanBase.copyWith(
              color: theme.colorScheme.primary,
              decoration: combined,
              decorationColor: theme.colorScheme.primary,
            );
            return TextSpan(
              text: s.text,
              children: s.children,
              style: effective,
              recognizer: rec,
            );
          }
          return s;
        }).toList();
      case 'img':
        final alt = node.attributes['alt'] ?? '';
        final placeholder = alt.isEmpty ? '[image]' : '[image: $alt]';
        return [TextSpan(text: placeholder, style: baseStyle)];
      case 'span':
      case 'sup':
      case 'sub':
      case 'mark':
        return _inlineSpans(node, theme, baseStyle: baseStyle);
      default:
        return _inlineSpans(node, theme, baseStyle: baseStyle);
    }
  }

  List<InlineSpan> _linkifyText(
    String text,
    ThemeData theme,
    TextStyle? baseStyle,
  ) {
    if (text.isEmpty) return const [];
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _urlRe.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(
            TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
      }
      final (url, trailing) = _splitTrailing(m.group(0)!);
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final rec = TapGestureRecognizer()..onTap = () => _openUrl(url);
        _recognizers.add(rec);
        final linkStyle = (baseStyle ?? const TextStyle()).copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary,
        );
        spans.add(TextSpan(
          text: url,
          style: linkStyle,
          recognizer: rec,
        ));
        if (trailing.isNotEmpty) {
          spans.add(TextSpan(text: trailing, style: baseStyle));
        }
      } else {
        spans.add(TextSpan(text: m.group(0)!, style: baseStyle));
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  (String, String) _splitTrailing(String raw) {
    var url = raw;
    var trailing = '';
    while (url.isNotEmpty) {
      final last = url[url.length - 1];
      final strip = '.,;:!?\'"'.contains(last) ||
          (last == ')' && !_balanced(url, '(', ')')) ||
          (last == ']' && !_balanced(url, '[', ']')) ||
          (last == '}' && !_balanced(url, '{', '}'));
      if (!strip) break;
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.postBodyOpenFailed(url))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.postBodyOpenError(e.toString()))),
        );
      }
    }
  }

  final Map<String, Future<Uint8List?>> _imageFutures = {};
}

/// One `<img>` from a post body, rendered with a fixed-aspect box that
/// matches the image's final size — so the placeholder and the loaded
/// image have the same height, and images finishing load never shift
/// surrounding content during scroll.
///
/// On the first visit to a URL the aspect ratio is unknown; a 16:9
/// placeholder is used until the image decodes, then the ratio is
/// cached in [HtmlImageCache] and used for every subsequent view of the
/// same URL. Since the common jitter case is scroll-back (same URLs
/// viewed repeatedly), the fast path — cached aspect — is jitter-free.
class _HtmlImage extends StatefulWidget {
  final String url;
  final String alt;
  final bool isSvg;
  final ThemeData theme;
  final HtmlImageCache? cache;

  /// When no cache is configured, fall back to `Image.network` (keeps
  /// the widget functional; only used defensively since every in-app
  /// caller passes the store's cache).
  final bool fallbackToNetwork;

  const _HtmlImage({
    required this.url,
    required this.alt,
    required this.isSvg,
    required this.theme,
    required this.cache,
    required this.fallbackToNetwork,
  });

  @override
  State<_HtmlImage> createState() => _HtmlImageState();
}

class _HtmlImageState extends State<_HtmlImage> {
  Uint8List? _bytes;
  double? _aspect;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _aspect = widget.cache?.aspectFor(widget.url);
    _load();
  }

  Future<void> _load() async {
    if (widget.fallbackToNetwork) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final bytes = await widget.cache!.getOrFetch(widget.url);
      if (!mounted) return;
      if (bytes == null) {
        setState(() {
          _loading = false;
          _error = true;
        });
        return;
      }
      // Resolve aspect ratio — cached or fresh from a bounded decode.
      var ratio = _aspect ?? widget.cache!.aspectFor(widget.url);
      if (ratio == null) {
        ratio =
            widget.isSvg ? _parseSvgAspect(bytes) : await _decodeAspect(bytes);
        if (ratio != null) {
          widget.cache!.cacheAspect(widget.url, ratio);
        }
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _aspect = ratio;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<double?> _decodeAspect(Uint8List bytes) async {
    try {
      // `targetWidth: 400` bounds the decode — extracting aspect ratio
      // from a 4000×3000 source otherwise allocates 48 MB just to read
      // two integers off the resulting ui.Image.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 400,
      );
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (w <= 0 || h <= 0) return null;
      return w / h;
    } catch (_) {
      return null;
    }
  }

  double? _parseSvgAspect(Uint8List bytes) {
    try {
      final text = utf8.decode(
        bytes.length > 4000 ? bytes.sublist(0, 4000) : bytes,
        allowMalformed: true,
      );
      // Preferred: viewBox="minX minY width height"
      final vb =
          RegExp(r'viewBox\s*=\s*["\x27]([^"\x27]+)["\x27]').firstMatch(text);
      if (vb != null) {
        final parts = vb.group(1)!.trim().split(RegExp(r'[\s,]+'));
        if (parts.length == 4) {
          final w = double.tryParse(parts[2]);
          final h = double.tryParse(parts[3]);
          if (w != null && h != null && w > 0 && h > 0) return w / h;
        }
      }
      // Fallback: width="…" height="…" on the <svg> element.
      final wm =
          RegExp(r'<svg[^>]*\swidth\s*=\s*["\x27]([0-9.]+)').firstMatch(text);
      final hm =
          RegExp(r'<svg[^>]*\sheight\s*=\s*["\x27]([0-9.]+)').firstMatch(text);
      if (wm != null && hm != null) {
        final w = double.tryParse(wm.group(1)!);
        final h = double.tryParse(hm.group(1)!);
        if (w != null && h != null && w > 0 && h > 0) return w / h;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // When the aspect is unknown (first view of a URL), assume 16:9 for
    // the placeholder. Once the image decodes, the real aspect is cached
    // and used from then on — so scroll-back has no layout shift.
    final aspect = _aspect ?? (16 / 9);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const maxHeight = 400.0;
            final availW = constraints.maxWidth;
            // Fit inside (availW, maxHeight), preserving aspect — the
            // same constraint the old ConstrainedBox(maxHeight: 400)
            // applied. Without the explicit height cap, tall images
            // (screenshots, portrait photos) would fill the full width
            // and become hundreds of pixels tall.
            final double w, h;
            if (availW / aspect > maxHeight) {
              h = maxHeight;
              w = maxHeight * aspect;
            } else {
              w = availW;
              h = availW / aspect;
            }

            return Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: w,
                height: h,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildContent(w),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(double displayWidth) {
    final theme = widget.theme;
    final l = context.l10n;

    if (widget.fallbackToNetwork) {
      if (widget.isSvg) return _imageErrorBox(widget.alt, theme, l);
      return Image.network(
        widget.url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imageErrorBox(widget.alt, theme, l),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _imageLoadingBox(theme);
        },
      );
    }
    if (_loading) return _imageLoadingBox(theme);
    if (_error || _bytes == null) return _imageErrorBox(widget.alt, theme, l);

    if (widget.isSvg) {
      if (!_looksLikeSvg(_bytes!)) return _imageErrorBox(widget.alt, theme, l);
      return SvgPicture.memory(_bytes!, fit: BoxFit.contain);
    }

    // Decode at display size × DPR, clamped to a sane range. Replaces
    // the previous hardcoded 800px, which was pixelated on high-DPI and
    // wasteful on small screens.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (displayWidth * dpr).round().clamp(100, 1600);

    return Image.memory(
      _bytes!,
      fit: BoxFit.contain,
      cacheWidth: cacheW,
      errorBuilder: (_, __, ___) => _imageErrorBox(widget.alt, theme, l),
    );
  }
}

// ── Shared image helpers ───────────────────────────────────────────────
// Top-level so both `_PostBodyTextState` and `_HtmlImageState` can use
// them. Stateless — pure functions of their arguments.

Widget _imagePlaceholder(String alt, ThemeData theme, AppLocalizations l) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        alt.isEmpty
            ? l.postBodyImagePlaceholder
            : l.postBodyImagePlaceholderAlt(alt),
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    ),
  );
}

Widget _imageErrorBox(String alt, ThemeData theme, AppLocalizations l) {
  return Container(
    height: 120,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                alt.isEmpty ? l.postBodyImageFailed : alt,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _imageLoadingBox(ThemeData theme) {
  return Container(
    height: 120,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

bool _looksLikeSvg(Uint8List bytes) {
  // Cheap sanity check: some servers return a 200 with an HTML error
  // page rather than a 404. Without this, `SvgPicture.memory` throws
  // during async parse and the framework shows a red error box.
  try {
    final prefix = utf8
        .decode(
          bytes.length > 500 ? bytes.sublist(0, 500) : bytes,
          allowMalformed: true,
        )
        .toLowerCase();
    return prefix.contains('<svg') || prefix.contains('<?xml');
  } catch (_) {
    return false;
  }
}
