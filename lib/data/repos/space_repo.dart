import 'dart:convert';

import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/html_utils.dart';
import '../../util/json_format.dart';
import '../models.dart';

/// Reads and writes space directories: `<vault>/<space-id>/space.json`
/// holds the frontmatter (id, name, icon, created). No body — the space
/// has no content of its own.
///
/// Legacy spaces may still have `space.html` (frontmatter block + a
/// decorative `<h1>`). Every method resolves the actual metadata file at
/// call time via [_readMeta]; writes always produce `space.json`. The
/// migration from HTML to JSON runs once at app startup via
/// [migrateHtmlToJson].
class SpaceRepository {
  final FileSystem fs;
  final String vaultPath;

  const SpaceRepository({required this.fs, required this.vaultPath});

  // ── Public API ─────────────────────────────────────────────────────────

  Future<List<Space>> list() async {
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return const [];

    final result = <Space>[];
    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      try {
        final space = await _read(p.basename(e.path));
        if (space != null) result.add(space);
      } catch (_) {
        // Skip broken space directories.
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<Space> create({required String name, String icon = '📓'}) async {
    final id = const Uuid().v7();
    final now = DateTime.now().toUtc();
    final dir = p.join(vaultPath, id);
    await fs.directory(p.join(dir, 'entries')).create(recursive: true);
    await fs.directory(p.join(dir, 'drive')).create(recursive: true);
    await fs
        .file(p.join(dir, 'drive_meta.json'))
        .writeAsString(prettyJson(const <String, dynamic>{}));
    final meta = <String, dynamic>{
      'id': id,
      'name': name,
      'icon': icon,
      'created': now.toIso8601String(),
    };
    await fs.file(p.join(dir, 'space.json')).writeAsString(prettyJson(meta));
    return Space(id: id, name: name, icon: icon, createdAt: now);
  }

  /// Rewrites `space.json` with new [name] and [icon], preserving the
  /// original `id` and `created`. If a legacy `space.html` is still present
  /// in the same directory, it is deleted after the successful write.
  Future<Space> update({
    required String spaceId,
    required String name,
    required String icon,
  }) async {
    final dir = p.join(vaultPath, spaceId);
    final existing = await _readMeta(spaceId);
    if (existing == null) {
      throw StateError('Space $spaceId not found');
    }
    final createdAt = DateTime.parse(existing['created'] as String);

    final updated = <String, dynamic>{
      'id': spaceId,
      'name': name,
      'icon': icon,
      'created': createdAt.toIso8601String(),
    };
    await fs.directory(dir).create(recursive: true);
    await fs
        .file(p.join(dir, 'space.json'))
        .writeAsString(prettyJson(updated));

    // Remove legacy HTML if it's still there. Failure is non-fatal —
    // migration will pick it up on the next reload.
    final htmlFile = fs.file(p.join(dir, 'space.html'));
    if (await htmlFile.exists()) {
      try {
        await htmlFile.delete();
      } catch (_) {}
    }

    return Space(
      id: spaceId,
      name: name,
      icon: icon,
      createdAt: createdAt,
    );
  }

  Future<void> delete(String spaceId) async {
    final dir = fs.directory(p.join(vaultPath, spaceId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ── Migration ──────────────────────────────────────────────────────────

  /// Converts every `space.html` in the vault to `space.json`.
  ///
  /// Idempotent: after a successful pass, no `space.html` remains, so
  /// subsequent calls are a no-op. If both files exist (e.g. a prior
  /// partial migration, or the user restored an old file manually),
  /// `space.json` wins and the `space.html` is removed.
  ///
  /// Verify-then-delete: the JSON is written and confirmed before the
  /// HTML is removed. A failure at any point leaves the space readable
  /// via the fallback in [_readMeta].
  Future<void> migrateHtmlToJson() async {
    final root = fs.directory(vaultPath);
    if (!await root.exists()) return;

    await for (final e in root.list(followLinks: false)) {
      if (e is! Directory) continue;
      final dirPath = e.path;
      final htmlFile = fs.file(p.join(dirPath, 'space.html'));
      if (!await htmlFile.exists()) continue;

      final jsonFile = fs.file(p.join(dirPath, 'space.json'));
      if (await jsonFile.exists()) {
        // Both present — space.json wins. Remove the stale HTML.
        try {
          await htmlFile.delete();
        } catch (err) {
          debugPrint(
              'Could not remove redundant space.html in $dirPath: $err');
        }
        continue;
      }

      try {
        final content = await htmlFile.readAsString();
        final meta = parseFrontmatterMeta(content);
        // Ensure the id matches the directory basename — the rest of the
        // app uses the directory as the canonical space id.
        meta['id'] = p.basename(dirPath);

        await jsonFile.writeAsString(prettyJson(meta));
        // Confirm the write before deleting the original.
        if (!await jsonFile.exists()) {
          debugPrint(
              'Migration verify failed for $dirPath; keeping space.html');
          continue;
        }
        await htmlFile.delete();
      } catch (err) {
        debugPrint(
            'Space migration failed for $dirPath: $err. '
            'Fallback read from space.html will still work.');
      }
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<Space?> _read(String id) async {
    final meta = await _readMeta(id);
    if (meta == null) return null;
    return Space(
      id: (meta['id'] as String?) ?? id,
      name: (meta['name'] as String?) ?? id,
      icon: (meta['icon'] as String?) ?? '📓',
      createdAt: DateTime.parse(meta['created'] as String),
    );
  }

  /// Reads metadata from whichever format is present, preferring
  /// `space.json`. Returns null when neither file exists.
  Future<Map<String, dynamic>?> _readMeta(String id) async {
    final dir = p.join(vaultPath, id);

    final jsonFile = fs.file(p.join(dir, 'space.json'));
    if (await jsonFile.exists()) {
      try {
        final raw = jsonDecode(await jsonFile.readAsString());
        if (raw is Map) return raw.cast<String, dynamic>();
      } catch (err) {
        debugPrint('Bad space.json for $id: $err');
      }
    }

    final htmlFile = fs.file(p.join(dir, 'space.html'));
    if (await htmlFile.exists()) {
      try {
        return parseFrontmatterMeta(await htmlFile.readAsString());
      } catch (err) {
        debugPrint('Bad space.html for $id: $err');
      }
    }

    return null;
  }
}