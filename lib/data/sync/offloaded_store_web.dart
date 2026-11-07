import 'dart:convert';

import 'package:web/web.dart' as web;

class OffloadedFileInfo {
  final String remoteSha;
  final int size;
  const OffloadedFileInfo({required this.remoteSha, required this.size});

  Map<String, dynamic> toJson() => {'remoteSha': remoteSha, 'size': size};

  factory OffloadedFileInfo.fromJson(Map<String, dynamic> j) =>
      OffloadedFileInfo(
        remoteSha: j['remoteSha'] as String,
        size: (j['size'] as int?) ?? 0,
      );
}

class OffloadedStore {
  const OffloadedStore();

  static String _key(String spaceId) => 'cartoria_offloaded_$spaceId';

  Future<Map<String, OffloadedFileInfo>> load(String spaceId) async {
    try {
      final raw = web.window.localStorage.getItem(_key(spaceId));
      if (raw == null || raw.isEmpty) return {};
      final map = jsonDecode(raw) as Map;
      return map.map((k, v) => MapEntry(
            k as String,
            OffloadedFileInfo.fromJson((v as Map).cast<String, dynamic>()),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(
      String spaceId, Map<String, OffloadedFileInfo> data) async {
    try {
      web.window.localStorage.setItem(
          _key(spaceId),
          jsonEncode(data.map((k, v) => MapEntry(k, v.toJson()))));
    } catch (_) {}
  }

  Future<OffloadedFileInfo?> get(String spaceId, String fileId) async {
    return (await load(spaceId))[fileId];
  }
}