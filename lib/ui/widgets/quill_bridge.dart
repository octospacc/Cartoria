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
    final rawDelta = HtmlToDelta().convert(encoded);
    final decoded = _decodeInlineCode(rawDelta.toJson());
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

/// Older saves used `ConverterOptions.forEmail()`, which turned inline
/// `<code>` into `<span style="font-family: monospace">`. Normalise
/// those back to semantic `<code>` so the marker encoder below finds
/// them. Also strips attributes from `<code class="…">` forms.
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

/// Replace inline `<code>text</code>` with marker-wrapped text, leaving
/// `<pre><code>` blocks untouched (they remain genuine block code
/// blocks). Markers survive HTML→Delta conversion as plain text, so
/// post-processing can reapply the `code` attribute reliably.
String _encodeInlineCode(String html) {
  // Protect <pre>…</pre> blocks first.
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

/// Split text ops at marker boundaries and apply `code: true` to the
/// content between `_codeOpen` and `_codeClose`. Handles markers and
/// content split across multiple ops (the converter may segment text
/// at formatting boundaries).
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
          break; // stay in code for the next op
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
  if (delta.isEmpty) return '';
  try {
    return QuillDeltaToHtmlConverter(delta, ConverterOptions()).convert().trim();
  } catch (_) {
    return '';
  }
}

String quillToDeltaJson(QuillController ctrl) =>
    jsonEncode(ctrl.document.toDelta().toJson());

String quillToPlaintext(QuillController ctrl) =>
    ctrl.document.toPlainText().trim();

/// True when [html] contains any inline formatting the plaintext editor
/// cannot represent. Used to decide whether to warn the user before
/// editing in plain mode.
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