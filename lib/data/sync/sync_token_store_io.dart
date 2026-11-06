import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../util/json_format.dart';

/// Provider tokens, stored outside the vault in the app support dir.
/// Keyed by `provider[:host]:owner/repo`.
class SyncTokenStore {
  final FileSystem fs;
  const SyncTokenStore({required this.fs});

  Future<String> _path() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'sync_tokens.json');
  }

  Future<Map<String, dynamic>> _readAll() async {
    final f = fs.file(await _path());
    if (!await f.exists()) return {};
    try {
      return (jsonDecode(await f.readAsString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final dir = await getApplicationSupportDirectory();
    await fs.directory(dir.path).create(recursive: true);
    await fs.file(await _path()).writeAsString(prettyJson(data));
  }

  Future<String?> load(String key) async => (await _readAll())[key] as String?;

  Future<void> save(String key, String token) async {
    final data = await _readAll();
    data[key] = token;
    await _writeAll(data);
  }

  Future<void> delete(String key) async {
    final data = await _readAll();
    data.remove(key);
    await _writeAll(data);
  }
}