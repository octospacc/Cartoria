import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Caches the last-seen remote file listing.
class SyncCacheStore {
  final FileSystem fs;
  const SyncCacheStore({required this.fs});

  Future<String> _path(String cacheKey) async {
    final dir = await getApplicationSupportDirectory();
    final safe = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return p.join(dir.path, 'sync_cache_$safe.json');
  }

  Future<({Map<String, String> files, String? commitSha})?> load(
    String cacheKey,
  ) async {
    final f = fs.file(await _path(cacheKey));
    if (!await f.exists()) return null;
    try {
      final data =
          (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
      final files =
          ((data['files'] as Map?) ?? const {}).cast<String, String>();
      return (files: files, commitSha: data['commitSha'] as String?);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    String cacheKey,
    Map<String, String> files,
    String? commitSha,
  ) async {
    final dir = await getApplicationSupportDirectory();
    await fs.directory(dir.path).create(recursive: true);
    await fs.file(await _path(cacheKey)).writeAsString(jsonEncode({
      'files': files,
      'commitSha': commitSha,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    }));
  }

  Future<void> clear(String cacheKey) async {
    final f = fs.file(await _path(cacheKey));
    if (await f.exists()) await f.delete();
  }
}