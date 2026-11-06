import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../util/json_format.dart';
import '../hooks.dart';
import '../models.dart';

/// Reads and writes vault-scoped hooks as individual
/// `<vault>/hooks/<key>.json` files — one hook per file.
///
/// Hooks live at the vault root (not inside any space) because a hook's
/// filters can span multiple spaces, or all of them. A single file per
/// hook keeps git diffs, merge conflicts, and copy-paste sharing aligned
/// with the per-hook granularity the UI already exposes.
///
/// The filename is the hook's `key` — filesystem enforces uniqueness, and
/// `ls hooks/` gives alphabetical order matching the UI's sorted list.
///
/// Legacy vaults with the pre-folder `<vault>/hooks.json` are migrated on
/// first load via [migrateSingleFileToFolder]. Both shapes are read by
/// [load] until the migration succeeds.
class HooksRepository {
  final FileSystem fs;
  final String vaultPath;

  final List<Hook> _cache = [];

  HooksRepository({required this.fs, required this.vaultPath});

  String get _legacyPath => p.join(vaultPath, 'hooks.json');
  String get _hooksDirPath => p.join(vaultPath, 'hooks');

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

  // ── Load ───────────────────────────────────────────────────────────────

  Future<void> load() async {
    _cache.clear();

    final dir = fs.directory(_hooksDirPath);
    if (!await dir.exists()) {
      await _loadFromLegacyIfPresent();
      return;
    }

    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final raw = jsonDecode(await e.readAsString());
        if (raw is Map) {
          _cache.add(Hook.fromJson(raw.cast<String, dynamic>()));
        } else {
          debugPrint('Skipping non-object hook file ${e.path}');
        }
      } catch (err) {
        debugPrint('Bad hook file ${e.path}: $err');
      }
    }

    // Creation order. Hook.id is UUIDv7, so lexicographic ascending = the
    // order the hooks were first created. Filenames (the hook keys) are
    // user-chosen and have no temporal meaning; sorting by them would
    // shuffle the list whenever a key was renamed.
    _cache.sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _loadFromLegacyIfPresent() async {
    final f = fs.file(_legacyPath);
    if (!await f.exists()) return;
    try {
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return;
      final list = (raw['hooks'] as List?) ?? const [];
      for (final e in list) {
        if (e is! Map) continue;
        try {
          _cache.add(Hook.fromJson((e as Map).cast<String, dynamic>()));
        } catch (err) {
          debugPrint('Bad legacy hook: $err');
        }
      }
      _cache.sort((a, b) => a.id.compareTo(b.id));
    } catch (err) {
      debugPrint('Bad legacy hooks.json: $err');
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────

  Future<void> save(Hook hook) async {
    for (final h in _cache) {
      if (h.id != hook.id && h.key == hook.key) {
        throw ArgumentError('Another hook already uses the key "${hook.key}"');
      }
    }

    await fs.directory(_hooksDirPath).create(recursive: true);

    final old = byId(hook.id);
    if (old != null && old.key != hook.key) {
      final oldFile = fs.file(p.join(_hooksDirPath, '${old.key}.json'));
      if (await oldFile.exists()) {
        try {
          await oldFile.delete();
        } catch (err) {
          debugPrint('Could not delete old hook file ${old.key}: $err');
        }
      }
    }

    await fs
        .file(p.join(_hooksDirPath, '${hook.key}.json'))
        .writeAsString(prettyJson(hook.toJson()));

    final idx = _cache.indexWhere((h) => h.id == hook.id);
    if (idx >= 0) {
      _cache[idx] = hook;
    } else {
      _cache.add(hook);
    }
    // Re-sort by id. A no-op for edits (position preserved) and a no-op
    // for additions (new uuid7 > all existing, so it already belongs at
    // the end) — kept for the case where _cache somehow got unordered.
    _cache.sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> delete(String id) async {
    final h = byId(id);
    if (h != null) {
      final f = fs.file(p.join(_hooksDirPath, '${h.key}.json'));
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (err) {
          debugPrint('Could not delete hook file ${h.key}: $err');
        }
      }
    }
    _cache.removeWhere((h) => h.id == id);
  }

  // ── Migration ──────────────────────────────────────────────────────────

  /// One-shot migration from the pre-folder single-file format
  /// (`<vault>/hooks.json`) to per-hook files (`<vault>/hooks/<key>.json`).
  ///
  /// Contract:
  ///   - No legacy file: no-op.
  ///   - Folder already exists: prefer it, delete the legacy file.
  ///   - Legacy file parseable and all hooks valid: write all files,
  ///     verify each, then delete the legacy file.
  ///   - Any validation or verification failure: roll back any files
  ///     already written, leave `hooks.json` intact for manual recovery.
  ///
  /// Every future run re-checks. A partial migration self-heals on the
  /// next app launch because the legacy file is only deleted after all
  /// N files are verified.
  Future<void> migrateSingleFileToFolder() async {
    final legacy = fs.file(_legacyPath);
    if (!await legacy.exists()) return;

    final dir = fs.directory(_hooksDirPath);
    if (await dir.exists()) {
      // Folder is present — the migration already ran, or the user
      // manually created per-hook files. Trust the folder.
      debugPrint('Both hooks.json and hooks/ exist; keeping hooks/, '
          'removing hooks.json');
      try {
        await legacy.delete();
      } catch (err) {
        debugPrint('Could not remove redundant hooks.json: $err');
      }
      return;
    }

    // Parse and validate the entire legacy file before writing anything.
    final valid = <Map<String, dynamic>>[];
    try {
      final raw = jsonDecode(await legacy.readAsString());
      if (raw is! Map) {
        throw const FormatException('hooks.json is not a JSON object');
      }
      final list = (raw['hooks'] as List?) ?? const [];
      for (final entry in list) {
        if (entry is! Map) {
          debugPrint('Malformed hook entry in hooks.json; aborting migration');
          return;
        }
        final hookJson = (entry as Map).cast<String, dynamic>();
        final key = hookJson['key'] as String?;
        if (key == null || !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
          debugPrint(
              'Hook in hooks.json has invalid key "$key"; aborting migration');
          return;
        }
        valid.add(hookJson);
      }
    } catch (err) {
      debugPrint('Could not read hooks.json: $err; leaving it in place');
      return;
    }

    if (valid.isEmpty) {
      // No hooks to migrate; the file is dead weight.
      try {
        await legacy.delete();
      } catch (_) {}
      return;
    }

    // Write every file, verify each one, then delete the legacy file.
    // Any failure rolls back the folder.
    final written = <File>[];
    try {
      await dir.create(recursive: true);
      for (final hookJson in valid) {
        final key = hookJson['key'] as String;
        final f = fs.file(p.join(_hooksDirPath, '$key.json'));
        await f.writeAsString(prettyJson(hookJson));
        // Verify before continuing: the file must exist and round-trip
        // through JSON with the same key.
        final check = await f.readAsString();
        final parsed = jsonDecode(check);
        if (parsed is! Map || (parsed['key'] as String?) != key) {
          throw StateError('Verification failed for $key');
        }
        written.add(f);
      }
      await legacy.delete();
    } catch (err) {
      debugPrint('Hook migration failed: $err. Rolling back ${written.length} '
          'file(s); hooks.json kept intact.');
      for (final f in written) {
        try {
          await f.delete();
        } catch (_) {}
      }
      try {
        final remaining = await dir.list(followLinks: false).toList();
        if (remaining.isEmpty) await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
