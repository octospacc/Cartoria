import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';

import '../platform/fs.dart';

/// SHA-addressed cache in the virtual filesystem at `/thumbcache/<sha>.jpg`.
/// Uses fs_shim's IndexedDB-backed web backend, so entries survive reloads.
class ThumbnailCache {
  const ThumbnailCache();

  FileSystem get _fs => createFs();

  Future<Uint8List?> get(String sha) async {
    try {
      final f = _fs.file('/thumbcache-v2/$sha.jpg');
      if (!await f.exists()) return null;
      return f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String sha, Uint8List bytes) async {
    try {
      final dir = _fs.directory('/thumbcache-v2');
      await dir.create(recursive: true);
      await _fs.file('/thumbcache-v2/$sha.jpg').writeAsBytes(bytes);
    } catch (_) {}
  }
}
