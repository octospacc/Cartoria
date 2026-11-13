import 'dart:typed_data';

import 'package:http/http.dart' as http;

class HtmlImageCache {
  static const int _maxEntries = 100;
  static const int _maxFileBytes = 10 * 1024 * 1024;
  static const Duration _fetchTimeout = Duration(seconds: 30);

  final Map<String, Uint8List> _cache = {};
  final Map<String, double> _aspect = {};
  final Map<String, Future<Uint8List?>> _inflight = {};

  double? aspectFor(String url) => _aspect[url];

  void cacheAspect(String url, double ratio) {
    if (ratio.isFinite && ratio > 0) _aspect[url] = ratio;
  }

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
        while (_cache.length > _maxEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _cache.clear();
    _aspect.clear();
    _inflight.clear();
  }
}