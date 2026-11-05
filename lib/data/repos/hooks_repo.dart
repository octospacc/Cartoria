import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;

import '../../util/json_format.dart';
import '../hooks.dart';
import '../models.dart';        // ← add this line

class HooksRepository {
  final FileSystem fs;
  final String vaultPath;

  final List<Hook> _cache = [];

  HooksRepository({required this.fs, required this.vaultPath});

  String get _path => p.join(vaultPath, 'hooks.json');

  List<Hook> get all => List.unmodifiable(_cache);

  Hook? byId(String id) {
    for (final h in _cache) {
      if (h.id == id) return h;
    }
    return null;
  }

  Hook? byKey(String key) {
    for (final h in _cache) {
      if (h.key == key) return h;
    }
    return null;
  }

  List<Hook> activeFor({
    required String spaceId,
    required HookTrigger trigger,
    required PostKind postKind,
    required Set<String> postTags,
  }) {
    return _cache
        .where((h) => h.matches(
              spaceId: spaceId,
              trigger: trigger,
              postKind: postKind,
              postTags: postTags,
            ))
        .toList();
  }

  Future<void> load() async {
    _cache.clear();
    final f = fs.file(_path);
    if (!await f.exists()) return;
    try {
      final raw = jsonDecode(await f.readAsString()) as Map;
      final list = (raw['hooks'] as List?) ?? const [];
      for (final e in list) {
        _cache.add(Hook.fromJson((e as Map).cast<String, dynamic>()));
      }
    } catch (_) {
      // Corrupt file: start empty rather than block startup.
    }
  }

  Future<void> save(Hook hook) async {
    for (final h in _cache) {
      if (h.id != hook.id && h.key == hook.key) {
        throw ArgumentError(
            'Another hook already uses the key "${hook.key}"');
      }
    }
    final idx = _cache.indexWhere((h) => h.id == hook.id);
    if (idx >= 0) {
      _cache[idx] = hook;
    } else {
      _cache.add(hook);
    }
    await _write();
  }

  Future<void> delete(String id) async {
    _cache.removeWhere((h) => h.id == id);
    await _write();
  }

  Future<void> _write() async {
    await fs.directory(vaultPath).create(recursive: true);
    // Pretty-printed so `hooks.json` reads in git and in a text editor.
    await fs.file(_path).writeAsString(prettyJson({
      'version': 1,
      'hooks': _cache.map((h) => h.toJson()).toList(),
    }));
  }
}