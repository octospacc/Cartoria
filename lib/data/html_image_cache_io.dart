import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HtmlImageCache {
  static const int _maxFileEntries = 300;
  static const int _maxMemoryEntries = 40;
  static const int _maxFileBytes = 15 * 1024 * 1024;
  static const Duration _fetchTimeout = Duration(seconds: 30);

  /// Byte-buffer LRU. Returns the *same* `Uint8List` instance per URL
  /// so `MemoryImage`'s `==` (byte identity) matches Flutter's
  /// `ImageCache` key — decoded images are reused across scroll-back
  /// instead of re-decoded.
  final Map<String, Uint8List> _memory = {};
  final Map<String, double> _aspect = {};
  final Map<String, Future<Uint8List?>> _inflight = {};

  double? aspectFor(String url) => _aspect[url];

  void cacheAspect(String url, double ratio) {
    if (ratio.isFinite && ratio > 0) _aspect[url] = ratio;
  }

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final dir =
        Directory(p.join(support.path, 'cartoria', 'html-image-cache'));
    await dir.create(recursive: true);
    return dir;
  }

  String _keyFor(String url) => sha256.convert(utf8.encode(url)).toString();

  Future<File> _fileFor(String url) async {
    final dir = await _dir();
    return File(p.join(dir.path, '${_keyFor(url)}.bin'));
  }

  Future<Uint8List?> get(String url) async {
    final mem = _memory.remove(url);
    if (mem != null) {
      _memory[url] = mem; // touch for LRU
      return mem;
    }
    try {
      final f = await _fileFor(url);
      if (!await f.exists()) return null;
      try {
        await f.setLastModified(DateTime.now());
      } catch (_) {}
      final bytes = await f.readAsBytes();
      _memory[url] = bytes;
      _trimMemory();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> getOrFetch(String url) async {
    final cached = await get(url);
    if (cached != null) return cached;
    final existing = _inflight[url];
    if (existing != null) return existing;
    final future = _fetchAndStore(url);
    _inflight[url] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(url);
    }
  }

  Future<Uint8List?> _fetchAndStore(String url) async {
    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(_fetchTimeout);
      if (resp.statusCode != 200) return null;
      final bytes = resp.bodyBytes;
      if (bytes.isEmpty) return null;
      _memory[url] = bytes;
      _trimMemory();
      if (bytes.length <= _maxFileBytes) {
        try {
          final f = await _fileFor(url);
          await f.writeAsBytes(bytes, flush: true);
          await _pruneFiles();
        } catch (_) {}
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _trimMemory() {
    while (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<void> _pruneFiles() async {
    try {
      final dir = await _dir();
      final entries = <({File f, DateTime m})>[];
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        try {
          entries.add((f: e, m: (await e.stat()).modified));
        } catch (_) {}
      }
      if (entries.length <= _maxFileEntries) return;
      entries.sort((a, b) => a.m.compareTo(b.m));
      final toDelete = entries.length - _maxFileEntries;
      for (var i = 0; i < toDelete; i++) {
        try {
          await entries[i].f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    _memory.clear();
    _aspect.clear();
    _inflight.clear();
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}