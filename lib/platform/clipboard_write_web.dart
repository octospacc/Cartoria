import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Writes [plaintext] and, when [html] is non-null, rich HTML to the
/// browser clipboard. Uses `navigator.clipboard.write` with a
/// `ClipboardItem` carrying both `text/html` and `text/plain`; falls
/// back to `writeText` for the plaintext-only path and to Flutter's
/// `Clipboard.setData` if the JS interop path fails (Safari without
/// permission, older browsers, etc.).
Future<void> copyToClipboard({
  required String plaintext,
  String? html,
}) async {
  if (html == null || html.isEmpty) {
    try {
      await web.window.navigator.clipboard.writeText(plaintext).toDart;
      return;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: plaintext));
      return;
    }
  }
  try {
    final htmlBlob = web.Blob(
      [html.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html'),
    );
    final plainBlob = web.Blob(
      [plaintext.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain'),
    );
    final data = <String, JSAny>{
      'text/html': htmlBlob,
      'text/plain': plainBlob,
    }.jsify() as JSObject;
    final item = web.ClipboardItem(data);
    await web.window.navigator.clipboard.write([item].toJS).toDart;
  } catch (_) {
    try {
      await web.window.navigator.clipboard.writeText(plaintext).toDart;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: plaintext));
    }
  }
}

/// Writes PNG-encoded image bytes to the browser clipboard.
Future<void> copyImageToClipboard(Uint8List pngBytes) async {
  final blob = web.Blob(
    [pngBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final data = <String, JSAny>{
    'image/png': blob,
  }.jsify() as JSObject;
  final item = web.ClipboardItem(data);
  await web.window.navigator.clipboard.write([item].toJS).toDart;
}