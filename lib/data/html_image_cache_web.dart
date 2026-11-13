import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// In-memory, per-session image cache for the web build.
///
/// Bounded by [_maxEntries] with FIFO eviction. Page reload clears it —
/// deliberately: iOS Safari's IndexedDB quota is small enough that a
/// persistent image cache competes with the vault's media, and the
/// first-load cost on reload is usually acceptable for a personal
/// archive. If persistence becomes important, the backend can be
/// swapped for `fs_shim`'s IndexedDB-backed directory without changing
/// call sites.
class HtmlImageCache {
  static const int _maxEntries = 100;
  static const int _maxFileBytes = 10 * 1024 * 1024;
  static const Duration _fetchTimeout = Duration(seconds: 30);

  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List?>> _inflight = {};

  Future<Uint8List?> get(String url) async => _cache[url];

  Future<Uint8List?> getOrFetch(String url) async {
    final cached = _cache[url];
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
      if (bytes.length <= _maxFileBytes) {
        _cache[url] = bytes;
        _prune();
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _prune() {
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<void> clear() async {
    _cache.clear();
    _inflight.clear();
  }
}