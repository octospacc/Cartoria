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

  Future<Map<String, ({int size, DateTime mtime, String sha})>> loadLocalShas(
      String cacheKey) async {
    final f = fs.file(await _shaPath(cacheKey));
    if (!await f.exists()) return {};
    try {
      final raw = jsonDecode(await f.readAsString()) as Map;
      return raw.map((k, v) {
        final m = (v as Map).cast<String, dynamic>();
        return MapEntry(k as String, (
          size: m['size'] as int,
          mtime: DateTime.parse(m['mtime'] as String),
          sha: m['sha'] as String,
        ));
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLocalShas(
    String cacheKey,
    Map<String, ({int size, DateTime mtime, String sha})> data,
  ) async {
    final dir = await getApplicationSupportDirectory();
    await fs.directory(dir.path).create(recursive: true);
    final safe = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final path = p.join(dir.path, 'local_shas_$safe.json');
    final json = data.map((k, v) => MapEntry(k, {
          'size': v.size,
          'mtime': v.mtime.toIso8601String(),
          'sha': v.sha,
        }));
    await fs.file(path).writeAsString(jsonEncode(json));
  }

  Future<String> _shaPath(String cacheKey) async {
    final dir = await getApplicationSupportDirectory();
    final safe = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return p.join(dir.path, 'local_shas_$safe.json');
  }
}
