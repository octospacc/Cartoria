import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// Builds a [QuillController] from a stored HTML body. Empty or
/// whitespace-only input produces an empty document. Malformed HTML
/// produces an empty document rather than throwing — losing the body
/// silently is bad, but breaking the composer on open is worse.
QuillController quillFromHtml(String html) {
  if (html.trim().isEmpty) {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }
  try {
    final deltaOps = HtmlToDelta().convert(html);
    return QuillController(
      document: Document.fromJson(deltaOps.toJson()),
      selection: const TextSelection.collapsed(offset: 0),
    );
  } catch (_) {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }
}

/// Builds a [QuillController] from a draft. Prefers the stored Delta
/// JSON when present; falls back to plaintext for legacy drafts.
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

/// Serialises the editor state as HTML for storage. Returns empty
/// string when the document has no content.
String quillToHtml(QuillController ctrl) {
  final delta = ctrl.document.toDelta().toJson();
  if (delta.isEmpty) return '';
  try {
    return QuillDeltaToHtmlConverter(
      delta,
      ConverterOptions(),
    ).convert().trim();
  } catch (_) {
    return '';
  }
}

/// Serialises the editor state as Delta JSON for drafts.
String quillToDeltaJson(QuillController ctrl) =>
    jsonEncode(ctrl.document.toDelta().toJson());

/// Plaintext form. Trims leading/trailing whitespace; collapses to
/// empty for an empty document.
String quillToPlaintext(QuillController ctrl) =>
    ctrl.document.toPlainText().trim();