import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:super_clipboard/super_clipboard.dart';

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

Future<List<ClipboardFile>> readClipboardFiles() async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) return const [];

  final reader = await clipboard.read();
  final stamp = DateTime.now().millisecondsSinceEpoch;

  // Prefer file URI — it preserves the original filename and format.
  // A copy from Photo Booth, for example, carries both PNG image data
  // AND a file URI pointing to a temp JPG; using the URI gives us the
  // real name ("Photo on <date>.jpg") instead of a generic
  // "pasted-<timestamp>.png". Finder-copied files also come through
  // here with their real names intact.
  if (reader.canProvide(Formats.fileUri)) {
    try {
      final uri = await reader.readValue(Formats.fileUri);
      if (uri != null && uri.isScheme('file')) {
        final file = File.fromUri(uri);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final name = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : 'pasted-$stamp';
          return [
            ClipboardFile(
              bytes: bytes,
              name: name,
              mimeType: _mimeForExtension(name),
            ),
          ];
        }
      }
    } catch (e) {
      debugPrint('Could not read clipboard file URI: $e');
    }
  }

  // Fall back to raw image data. This is the path taken for screenshots
  // and copied-image-from-website cases, which don't carry a file URI.
  final png = await _readBinary(reader, Formats.png);
  if (png != null) {
    return [
      ClipboardFile(
        bytes: png,
        name: 'pasted-$stamp.png',
        mimeType: 'image/png',
      ),
    ];
  }
  final jpeg = await _readBinary(reader, Formats.jpeg);
  if (jpeg != null) {
    return [
      ClipboardFile(
        bytes: jpeg,
        name: 'pasted-$stamp.jpg',
        mimeType: 'image/jpeg',
      ),
    ];
  }
  return const [];
}

Future<Uint8List?> _readBinary(
  ClipboardReader reader,
  FileFormat format,
) async {
  if (!reader.canProvide(format)) return null;
  final completer = Completer<Uint8List?>();
  reader.getFile(format, (file) async {
    try {
      final bytes = await file.readAll();
      completer.complete(bytes);
    } catch (e, st) {
      completer.completeError(e, st);
    }
  });
  try {
    return await completer.future;
  } catch (e) {
    debugPrint('Could not read clipboard format: $e');
    return null;
  }
}

/// No-op on native platforms: paste events are handled by the OS text
/// pipeline and Flutter's TextField consumes them as text. Use the
/// "Paste from clipboard" menu option instead.
Widget withClipboardPasteListener({
  required Widget child,
  required void Function(List<ClipboardFile>) onFiles,
}) =>
    child;

String _mimeForExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return 'application/octet-stream';
  switch (name.substring(dot + 1).toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'mp3':
      return 'audio/mpeg';
    case 'txt':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}