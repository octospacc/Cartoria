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