import 'dart:js_interop';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Writes [plaintext] and, when [html] is non-null, rich HTML to the
/// browser clipboard. Uses `navigator.clipboard.write` with a
/// `ClipboardItem` carrying both `text/html` and `text/plain`; falls
/// back to `writeText` for plaintext-only paths and to Flutter's
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
    final data = js_util.jsify({}) as JSObject;
    js_util.setProperty(data, 'text/html', htmlBlob);
    js_util.setProperty(data, 'text/plain', plainBlob);
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