import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Disk-backed cache for `<img>` bytes referenced from post HTML bodies.
///
/// Two problems it solves:
///   1. `Image.network` uses Flutter's in-memory `ImageCache`, which is
///      cleared on scroll-off and on app restart — the same URL gets
///      re-downloaded every time the post re-enters the viewport.
///   2. The SVG path does a raw `http.get` per widget build (no cache at
///      all), so SVG images are re-fetched on every scroll-back.
///
/// Keyed by SHA-256 of the URL. Bounded by [_maxEntries] with LRU
/// eviction by mtime. Fetch failures are not cached; concurrent requests
/// for the same URL share one in-flight `Future`.
class HtmlImageCache {
  static const int _maxEntries = 300;
  static const int _maxFileBytes = 15 * 1024 * 1024;
  static const Duration _fetchTimeout = Duration(seconds: 30);

  final Map<String, Future<Uint8List?>> _inflight = {};

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(support.path, 'cartoria', 'html-image-cache'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  String _keyFor(String url) =>
      sha256.convert(utf8.encode(url)).toString();

  Future<File> _fileFor(String url) async {
    final dir = await _dir();
    return File(p.join(dir.path, '${_keyFor(url)}.bin'));
  }

  /// Returns cached bytes, or null on miss.
  Future<Uint8List?> get(String url) async {
    try {
      final f = await _fileFor(url);
      if (!await f.exists()) return null;
      // Touch mtime so LRU keeps this entry hot.
      try {
        await f.setLastModified(DateTime.now());
      } catch (_) {}
      return f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Returns bytes, fetching over the network on miss. Null on any
  /// failure (which is not cached — the next caller retries).
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
      // Cache only below the size cap. Larger responses still render,
      // just without persistence (a 500 MB video referenced in a note
      // shouldn't fill the disk).
      if (bytes.length <= _maxFileBytes) {
        await _store(url, bytes);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _store(String url, Uint8List bytes) async {
    try {
      final f = await _fileFor(url);
      await f.writeAsBytes(bytes, flush: true);
      await _prune();
    } catch (_) {}
  }

  Future<void> _prune() async {
    try {
      final dir = await _dir();
      final entries = <({File f, DateTime m})>[];
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        try {
          entries.add((f: e, m: (await e.stat()).modified));
        } catch (_) {}
      }
      if (entries.length <= _maxEntries) return;
      entries.sort((a, b) => a.m.compareTo(b.m));
      final toDelete = entries.length - _maxEntries;
      for (var i = 0; i < toDelete; i++) {
        try {
          await entries[i].f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      _inflight.clear();
      final dir = await _dir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}