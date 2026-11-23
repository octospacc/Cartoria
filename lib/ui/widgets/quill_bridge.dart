import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

// Private-use characters used as markers. They never appear in real
// text, so encoding/decoding is lossless for all practical content.
const _codeOpen = '\uE000';
const _codeClose = '\uE001';
const _preOpen = '\uE002';
const _preClose = '\uE003';

QuillController quillFromHtml(String html) {
  if (html.trim().isEmpty) {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }
  try {
    final normalized = _normalizeCodeTags(html);
    final encoded = _encodeInlineCode(normalized);
    final rawOps = _convertHtmlBlocks(encoded);
    final decoded = _decodeInlineCode(rawOps);
    return QuillController(
      document: Document.fromJson(decoded),
      selection: const TextSelection.collapsed(offset: 0),
    );
  } catch (_) {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }
}

/// Converts [html] block-by-block and joins the resulting deltas with
/// explicit paragraph separators.
///
/// `flutter_quill_delta_from_html` has a known bug where adjacent
/// top-level blocks (`<p>first</p><p>second</p>`) are merged into a
/// single text run without the paragraph separator that Quill uses to
/// mark a block boundary. Converting each block in isolation gives the
/// library the shape it expects, and we insert the separator ourselves.
List<dynamic> _convertHtmlBlocks(String html) {
  final blocks = _splitTopLevelBlocks(html);
  if (blocks.length <= 1) {
    return HtmlToDelta().convert(html).toJson();
  }
  final result = <dynamic>[];
  for (var i = 0; i < blocks.length; i++) {
    List<dynamic> ops;
    try {
      ops = HtmlToDelta().convert(blocks[i]).toJson();
    } catch (_) {
      ops = <dynamic>[];
    }
    // The library converts via markdown, which emits a blank line
    // after headings and blockquotes. Strip those so each block
    // contributes exactly one terminator newline. Attributed
    // newlines (block terminators, e.g. `{insert: "\n", attributes:
    // {header: 1}}`) are preserved — only plain `{insert: "\n"}`
    // trailing ops are removed.
    _stripTrailingEmptyNewlines(ops);
    result.addAll(ops);
    if (!_endsWithNewline(result)) {
      result.add({'insert': '\n'});
    }
  }
  return result;
}

/// Removes trailing `{insert: "\n"}` ops that carry no attributes.
/// Such ops represent empty paragraphs (the blank line markdown emits
/// after a heading or blockquote) rather than meaningful block
/// terminators, which always carry an `attributes` map identifying
/// the block type.
void _stripTrailingEmptyNewlines(List<dynamic> ops) {
  while (ops.isNotEmpty) {
    final last = ops.last;
    if (last is Map) {
      final ins = last['insert'];
      final attrs = last['attributes'];
      if (ins == '\n' && (attrs == null || (attrs is Map && attrs.isEmpty))) {
        ops.removeLast();
        continue;
      }
    }
    break;
  }
}

bool _endsWithNewline(List<dynamic> ops) {
  if (ops.isEmpty) return false;
  final last = ops.last;
  if (last is! Map) return false;
  final ins = last['insert'];
  return ins is String && ins.endsWith('\n');
}

/// Splits [html] at top-level `p`, `h1`–`h6`, `blockquote`, and `pre`
/// element boundaries. Nested blocks (list items, spans inside a
/// paragraph) stay inside their parent block.
List<String> _splitTopLevelBlocks(String html) {
  final re = RegExp(
    r'<(p|h[1-6]|blockquote|pre)\b[^>]*>[\s\S]*?</\1\s*>',
    caseSensitive: false,
  );
  final blocks = <String>[];
  var cursor = 0;
  for (final m in re.allMatches(html)) {
    if (m.start > cursor) {
      final gap = html.substring(cursor, m.start).trim();
      if (gap.isNotEmpty) blocks.add(gap);
    }
    blocks.add(m.group(0)!);
    cursor = m.end;
  }
  if (cursor < html.length) {
    final trailing = html.substring(cursor).trim();
    if (trailing.isNotEmpty) blocks.add(trailing);
  }
  return blocks;
}

String _normalizeCodeTags(String html) {
  var out = html.replaceAllMapped(
    RegExp(
      r'<span\s+style="[^"]*font-family:\s*monospace[^"]*">(.*?)</span>',
      dotAll: true,
      caseSensitive: false,
    ),
    (m) => '<code>${m[1]}</code>',
  );
  out = out.replaceAllMapped(
    RegExp(
      r'<code\b[^>]*>(.*?)</code\s*>',
      dotAll: true,
      caseSensitive: false,
    ),
    (m) => '<code>${m[1]}</code>',
  );
  return out;
}

String _encodeInlineCode(String html) {
  final preBlocks = <String>[];
  final protected = html.replaceAllMapped(
    RegExp(r'<pre\b[^>]*>.*?</pre\s*>',
        dotAll: true, caseSensitive: false),
    (m) {
      preBlocks.add(m.group(0)!);
      return '$_preOpen${preBlocks.length - 1}$_preClose';
    },
  );
  final encoded = protected
      .replaceAll(RegExp(r'<code\b[^>]*>', caseSensitive: false), _codeOpen)
      .replaceAll(RegExp(r'</code\s*>', caseSensitive: false), _codeClose);
  var restored = encoded;
  for (var i = 0; i < preBlocks.length; i++) {
    restored = restored.replaceAll('$_preOpen$i$_preClose', preBlocks[i]);
  }
  return restored;
}

List<dynamic> _decodeInlineCode(List<dynamic> ops) {
  final result = <dynamic>[];
  var inCode = false;

  for (final op in ops) {
    if (op is! Map) {
      result.add(op);
      continue;
    }
    final insert = op['insert'];
    if (insert is! String) {
      result.add(op);
      continue;
    }

    final text = insert as String;
    var i = 0;
    while (i < text.length) {
      if (!inCode) {
        final start = text.indexOf(_codeOpen, i);
        if (start < 0) {
          if (i < text.length) {
            result.add(_withInsert(op, text.substring(i)));
          }
          break;
        }
        if (start > i) {
          result.add(_withInsert(op, text.substring(i, start)));
        }
        inCode = true;
        i = start + 1;
      } else {
        final end = text.indexOf(_codeClose, i);
        if (end < 0) {
          final codeText = text.substring(i);
          if (codeText.isNotEmpty) {
            final codeOp = _withInsert(op, codeText);
            _applyCodeAttr(codeOp);
            result.add(codeOp);
          }
          break;
        }
        final codeText = text.substring(i, end);
        if (codeText.isNotEmpty) {
          final codeOp = _withInsert(op, codeText);
          _applyCodeAttr(codeOp);
          result.add(codeOp);
        }
        inCode = false;
        i = end + 1;
      }
    }
  }
  return result;
}

Map<String, dynamic> _withInsert(Map op, String newInsert) {
  final copy = Map<String, dynamic>.from(op as Map);
  copy['insert'] = newInsert;
  return copy;
}

void _applyCodeAttr(Map<String, dynamic> op) {
  final attrs = op['attributes'];
  final next = attrs is Map
      ? Map<String, dynamic>.from(attrs as Map)
      : <String, dynamic>{};
  next['code'] = true;
  op['attributes'] = next;
}

QuillController quillFromDraft({required String body, String? bodyDelta}) {
  if (bodyDelta != null && bodyDelta.isNotEmpty) {
    try {
      final json = jsonDecode(bodyDelta);
      if (json is List) {
        return QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {}
  }
  final document = Document();
  if (body.isNotEmpty) document.insert(0, body);
  return QuillController(
    document: document,
    selection: TextSelection.collapsed(offset: body.length),
  );
}

String quillToHtml(QuillController ctrl) {
  final delta = ctrl.document.toDelta().toJson();
  if (_isEmptyDelta(delta)) return '';
  try {
    return QuillDeltaToHtmlConverter(delta, ConverterOptions()).convert().trim();
  } catch (_) {
    return '';
  }
}

/// A freshly created `Document()` has delta `[{insert: "\n"}]` — not an
/// empty list. Standard `isEmpty` never fires, and the converter would
/// produce `<p><br/></p>`. Detects the minimal-empty form so
/// `quillToHtml` returns `''` for a blank document.
bool _isEmptyDelta(List<dynamic> delta) {
  if (delta.isEmpty) return true;
  if (delta.length == 1) {
    final op = delta.first;
    if (op is Map && op['insert'] == '\n') {
      final attrs = op['attributes'];
      if (attrs == null || (attrs is Map && attrs.isEmpty)) {
        return true;
      }
    }
  }
  return false;
}

String quillToDeltaJson(QuillController ctrl) =>
    jsonEncode(ctrl.document.toDelta().toJson());

String quillToPlaintext(QuillController ctrl) =>
    ctrl.document.toPlainText().trim();

bool htmlHasInlineFormatting(String html) {
  if (html.isEmpty) return false;
  final lower = html.toLowerCase();
  return lower.contains('<strong') ||
      lower.contains('<b>') ||
      lower.contains('<em') ||
      lower.contains('<i>') ||
      lower.contains('<u>') ||
      lower.contains('<s>') ||
      lower.contains('<del') ||
      lower.contains('<code') ||
      lower.contains('font-family: monospace');
}