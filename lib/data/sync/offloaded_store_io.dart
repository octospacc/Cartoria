import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

/// Per-space records of files that exist in the vault's `drive_meta.json`
/// but not on disk. Stored outside the vault (app support dir), keyed by
/// space id. Never synced, never exported, never walked by pull/push as
/// vault data.
class OffloadedStore {
  const OffloadedStore();

  Future<String> _path(String spaceId) async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'cartoria', 'offloaded', '$spaceId.json');
  }

  Future<Map<String, OffloadedFileInfo>> load(String spaceId) async {
    final dir = await getApplicationSupportDirectory();
    await Directory(p.join(dir.path, 'cartoria', 'offloaded'))
        .create(recursive: true);
    final file = File(await _path(spaceId));
    if (!await file.exists()) return {};
    try {
      final raw = jsonDecode(await file.readAsString()) as Map;
      return raw.map((k, v) => MapEntry(
            k as String,
            OffloadedFileInfo.fromJson((v as Map).cast<String, dynamic>()),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(
      String spaceId, Map<String, OffloadedFileInfo> data) async {
    final dir = await getApplicationSupportDirectory();
    await Directory(p.join(dir.path, 'cartoria', 'offloaded'))
        .create(recursive: true);
    await File(await _path(spaceId))
        .writeAsString(jsonEncode(data.map((k, v) => MapEntry(k, v.toJson()))));
  }

  Future<OffloadedFileInfo?> get(String spaceId, String fileId) async {
    return (await load(spaceId))[fileId];
  }
}