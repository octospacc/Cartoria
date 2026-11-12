import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class ClipboardFile {
  final Uint8List bytes;
  final String name;
  final String mimeType;

  const ClipboardFile({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
}

/// Reads images from the async clipboard API.
///
/// Requires a user gesture (the button tap) and permission (Chrome/Safari
/// prompt on first use). Firefox does not implement `clipboard.read()` for
/// arbitrary formats — in that case this returns an empty list and the
/// caller should direct the user to Ctrl+V instead.
Future<List<ClipboardFile>> readClipboardFiles() async {
  try {
    final items = await web.window.navigator.clipboard.read().toDart;
    final results = <ClipboardFile>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;

    for (final item in items.toDart) {
      final types = item.types.toDart;
      for (final type in types) {
        final typeStr = type.toDart;
        if (typeStr != 'image/png' && typeStr != 'image/jpeg') continue;
        final blob = await item.getType(typeStr).toDart;
        final buffer = await blob.arrayBuffer().toDart;
        final bytes = buffer.toDart.asUint8List();
        results.add(ClipboardFile(
          bytes: bytes,
          name: 'pasted-$stamp.${typeStr == 'image/png' ? 'png' : 'jpg'}',
          mimeType: typeStr,
        ));
        break; // one format per item is enough
      }
    }
    return results;
  } catch (_) {
    return const [];
  }
}

/// Listens for `paste` events on the document. When the pasted content
/// contains files/images, `preventDefault` is called (synchronously,
/// before any awaits) and [onFiles] fires. Text pastes pass through
/// normally.
///
/// Attached globally to `document`, not scoped to a specific widget —
/// the paste event only fires when *something* has focus, and in the
/// app that means a text field or button, both fine. The one caveat is
/// that pasting an image while the search field is focused will attach
/// to the post being composed; acceptable, since nobody pastes images
/// into a search box intentionally.
Widget withClipboardPasteListener({
  required Widget child,
  required void Function(List<ClipboardFile>) onFiles,
}) {
  return _ClipboardPasteWrapper(onFiles: onFiles, child: child);
}

class _ClipboardPasteWrapper extends StatefulWidget {
  final Widget child;
  final void Function(List<ClipboardFile>) onFiles;

  const _ClipboardPasteWrapper({
    required this.child,
    required this.onFiles,
  });

  @override
  State<_ClipboardPasteWrapper> createState() =>
      _ClipboardPasteWrapperState();
}

class _ClipboardPasteWrapperState extends State<_ClipboardPasteWrapper> {
  JSFunction? _listener;

  @override
  void initState() {
    super.initState();
    _listener = ((web.Event e) {
      final ce = e as web.ClipboardEvent;
      final data = ce.clipboardData;
      if (data == null) return;
      final items = data.items;
      final files = <web.File>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item.kind != 'file') continue;
        final f = item.getAsFile();
        if (f != null) files.add(f);
      }
      if (files.isEmpty) return;
      // Must be synchronous, before any await — otherwise the default
      // action (paste into the focused field) has already happened.
      ce.preventDefault();
      _processFiles(files).then(widget.onFiles);
    }).toJS;
    web.document.addEventListener('paste', _listener);
  }

  @override
  void dispose() {
    final l = _listener;
    if (l != null) {
      web.document.removeEventListener('paste', l);
    }
    super.dispose();
  }

  Future<List<ClipboardFile>> _processFiles(List<web.File> files) async {
    final result = <ClipboardFile>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final f in files) {
      try {
        final buffer = await f.arrayBuffer().toDart;
        final bytes = buffer.toDart.asUint8List();
        final mime = f.type;
        final ext = mime.contains('/') ? mime.split('/').last : 'bin';
        final name = f.name.isEmpty ? 'pasted-$stamp.$ext' : f.name;
        result.add(ClipboardFile(
          bytes: bytes,
          name: name,
          mimeType: mime.isEmpty ? 'application/octet-stream' : mime,
        ));
      } catch (_) {
        // Skip files that fail to read; the rest still attach.
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}