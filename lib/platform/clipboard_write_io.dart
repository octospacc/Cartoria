import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Writes [plaintext] and, when [html] is non-null, rich HTML to the
/// system clipboard. On native platforms this goes through
/// `super_clipboard`, which handles the platform-specific clipboard
/// formats (NSPasteboard types on macOS, IDataObject on Windows, X11
/// selection targets on Linux, and so on) transparently. If rich
/// writing fails for any reason, falls back to plaintext so the copy
/// is never lost entirely.
Future<void> copyToClipboard({
  required String plaintext,
  String? html,
}) async {
  if (html == null || html.isEmpty) {
    await Clipboard.setData(ClipboardData(text: plaintext));
    return;
  }
  try {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      throw StateError('Clipboard unavailable');
    }
    final item = DataWriterItem();
    item.add(Formats.htmlText(html));
    item.add(Formats.plainText(plaintext));
    await clipboard.write([item]);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: plaintext));
  }
}

Future<void> copyImageBytesToClipboard(
  Uint8List bytes,
  String mimeType,
) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) throw StateError('Clipboard unavailable');

  final item = DataWriterItem();
  try {
    final format = _formatForMime(mimeType);
    item.add(format(bytes));
  } catch (_) {
    // Fallback: re-encode to PNG for formats the clipboard can't carry
    // natively (HEIC, BMP, etc.). Rare; slow path only for those.
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final pngData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (pngData == null) throw StateError('encode failed');
    item.add(Formats.png(pngData.buffer.asUint8List()));
  }
  await clipboard.write([item]);
}

FileFormat _formatForMime(String mime) {
  switch (mime) {
    case 'image/png':
      return Formats.png;
    case 'image/jpeg':
    case 'image/jpg':
      return Formats.jpeg;
    case 'image/gif':
      return Formats.gif;
    case 'image/webp':
      return Formats.webp;
    default:
      throw UnsupportedError('mime: $mime');
  }
}
