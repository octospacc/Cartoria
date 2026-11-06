import 'dart:convert';
import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/json_format.dart';
import '../space_archive.dart';
import '../models.dart';

/// Stores opaque file blobs under `drive/<id>.<ext>` (or `drive/<id>` for
/// extensionless names) and their metadata under `drive_meta.json`.
///
/// On-disk filenames carry the file's extension so that Git forges render
/// previews, `.gitattributes` matches work, and clones are recognisable
/// at a glance. The `id` remains the primary key — the extension is
/// presentation only and is ignored when resolving a file.
///
/// Files created before this scheme existed are named `<id>` (no
/// extension). They are renamed lazily on first access: for each legacy
/// file whose metadata `name` has an extension, the file is renamed to
/// `<id>.<ext>`. The rename is one-time per space, and the next sync
/// shows it as a rename (or delete+create on GitLab).
class DriveRepository {
  final FileSystem fs;
  final String vaultPath;

  /// `spaceId` → (`fileId` → full on-disk path). Rebuilt lazily; cleared
  /// by [clearCache]. Necessary because [readBytes] must resolve an `id`
  /// to `id` or `id.ext` — both forms coexist during and after migration.
  final Map<String, Map<String, String>> _pathCache = {};

  DriveRepository({required this.fs, required this.vaultPath});

  // ── Public API ─────────────────────────────────────────────────────────

  Future<List<DriveFile>> list(String spaceId) async {
    final meta = await _readMeta(spaceId);
    if (meta.isEmpty) return const [];

    final index = await _driveIndex(spaceId);
    final result = <DriveFile>[];
    for (final entry in meta.entries) {
      final id = entry.key;
      final m = entry.value;
      final path = index[id];
      if (path == null) continue;
      try {
        final file = fs.file(path);
        result.add(DriveFile(
          id: id,
          name: (m['name'] as String?) ?? id,
          sizeBytes: (await file.stat()).size,
          createdAt: DateTime.parse(m['created'] as String),
        ));
      } catch (err) {
        debugPrint('Bad drive file $id: $err');
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<DriveFile> addBytes({
    required String spaceId,
    required Uint8List bytes,
    required String name,
  }) async {
    final id = const Uuid().v7();
    final now = DateTime.now().toUtc();
    final ext = _sanitizedExtension(name);
    final diskName = ext.isEmpty ? id : '$id.$ext';
    final path = p.join(vaultPath, spaceId, 'drive', diskName);

    await fs
        .directory(p.join(vaultPath, spaceId, 'drive'))
        .create(recursive: true);
    await fs.file(path).writeAsBytes(bytes);

    final meta = await _readMeta(spaceId);
    meta[id] = {'name': name, 'created': now.toIso8601String()};
    await _writeMeta(spaceId, meta);

    // Update the index in-place rather than invalidating it — files never
    // change their on-disk name after creation.
    final index = await _driveIndex(spaceId);
    index[id] = path;

    return DriveFile(
      id: id,
      name: name,
      sizeBytes: bytes.length,
      createdAt: now,
    );
  }

  Future<Uint8List> readBytes(String spaceId, String fileId) async {
    final index = await _driveIndex(spaceId);
    final path = index[fileId];
    if (path == null) {
      throw StateError('Drive file $fileId not found in space $spaceId');
    }
    return fs.file(path).readAsBytes();
  }

  Future<void> delete(String spaceId, String fileId) async {
    final index = await _driveIndex(spaceId);
    final path = index.remove(fileId);
    if (path != null) {
      final f = fs.file(path);
      if (await f.exists()) await f.delete();
    }
    final meta = await _readMeta(spaceId);
    meta.remove(fileId);
    await _writeMeta(spaceId, meta);
  }

  /// Deletes multiple files with one metadata read/write. The individual
  /// blob deletes are still one per file, but the expensive
  /// `drive_meta.json` round-trip happens once for the whole batch.
  Future<void> deleteMultiple(String spaceId, Set<String> fileIds) async {
    if (fileIds.isEmpty) return;

    final index = await _driveIndex(spaceId);
    for (final id in fileIds) {
      final path = index.remove(id);
      if (path == null) continue;
      try {
        final f = fs.file(path);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Failed to delete drive file $id: $e');
      }
    }

    final meta = await _readMeta(spaceId);
    for (final id in fileIds) {
      meta.remove(id);
    }
    await _writeMeta(spaceId, meta);
  }

  /// Drops the path cache for all spaces. Called from `VaultStore.reload`
  /// so external changes (imports, pulls, manual edits) are picked up.
  void clearCache() {
    _pathCache.clear();
  }

  // ── Index building + migration ─────────────────────────────────────────

  Future<Map<String, String>> _driveIndex(String spaceId) async {
    final cached = _pathCache[spaceId];
    if (cached != null) return cached;

    final index = await _buildIndex(spaceId);
    _pathCache[spaceId] = index;
    return index;
  }

  Future<Map<String, String>> _buildIndex(String spaceId) async {
    final out = <String, String>{};
    final driveDir = fs.directory(p.join(vaultPath, spaceId, 'drive'));
    if (!await driveDir.exists()) return out;

    final meta = await _readMeta(spaceId);

    // Collect every file on disk, grouped by id. Both `<id>` (legacy) and
    // `<id>.<ext>` (current) resolve to the same id — take whichever exists.
    final byId = <String, List<File>>{};
    await for (final e in driveDir.list(followLinks: false)) {
      if (e is! File) continue;
      final base = p.basename(e.path);
      final dot = base.indexOf('.');
      final id = dot < 0 ? base : base.substring(0, dot);
      byId.putIfAbsent(id, () => []).add(e);
    }

    for (final entry in byId.entries) {
      final id = entry.key;
      final candidates = entry.value;
      final metaName = meta[id]?['name'];

      // Prefer a candidate whose extension matches the metadata name
      // (current scheme); otherwise take the first (legacy).
      File chosen = candidates.first;
      if (metaName is String) {
        final wantExt = _sanitizedExtension(metaName);
        if (wantExt.isNotEmpty) {
          for (final f in candidates) {
            if (p.extension(f.path).toLowerCase() == '.$wantExt') {
              chosen = f;
              break;
            }
          }
        }
      }

      // Migrate a legacy file to the current scheme if its metadata name
      // declares an extension and the file is still bare `<id>`.
      if (metaName is String) {
        final base = p.basename(chosen.path);
        final hasExtOnDisk = base.contains('.');
        if (!hasExtOnDisk) {
          final ext = _sanitizedExtension(metaName);
          if (ext.isNotEmpty) {
            final newPath = p.join(p.dirname(chosen.path), '$id.$ext');
            try {
              await fs.file(chosen.path).rename(newPath);
              chosen = fs.file(newPath);
            } catch (e) {
              debugPrint('Migration rename failed for $id: $e');
              // Keep the old path.
            }
          }
        }
      }

      out[id] = chosen.path;
    }

    return out;
  }

  /// Returns the lowercase extension without the leading dot, filtered to
  /// `[a-z0-9]`. Empty when the name has no extension (including dotfiles
  /// like `.env`) or the trailing segment contains no valid characters.
  String _sanitizedExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == 0) return '';
    final raw = name.substring(dot + 1);
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // ── drive_meta.json ────────────────────────────────────────────────────

  Future<Map<String, Map<String, dynamic>>> _readMeta(String spaceId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'drive_meta.json'));
    if (!await f.exists()) return {};
    final raw = jsonDecode(await f.readAsString()) as Map;
    return raw.map(
        (k, v) => MapEntry(k as String, (v as Map).cast<String, dynamic>()));
  }

  Future<void> _writeMeta(
      String spaceId, Map<String, Map<String, dynamic>> meta) async {
    // `jsonDecode` accepts any whitespace, so the pretty-printed form is
    // read back identically. `prettyJson` ends with a trailing newline,
    // which matters for git diffs.
    await fs
        .file(p.join(vaultPath, spaceId, 'drive_meta.json'))
        .writeAsString(prettyJson(meta));
  }

// Add to the DriveRepository class.

  /// Writes multiple pre-read files into [spaceId] with one metadata write.
  /// Skips ids in [existingIds]. Returns the DriveFile records created.
  Future<List<DriveFile>> importExistingFiles({
    required String spaceId,
    required Map<String, ExtractedFile> files,
    required Set<String> existingIds,
  }) async {
    if (files.isEmpty) return const [];
    await fs
        .directory(p.join(vaultPath, spaceId, 'drive'))
        .create(recursive: true);

    final meta = await _readMeta(spaceId);
    final index = await _driveIndex(spaceId);
    final result = <DriveFile>[];

    for (final entry in files.entries) {
      final id = entry.key;
      final ef = entry.value;
      if (existingIds.contains(id)) continue;
      final ext = _sanitizedExtension(ef.name);
      final diskName = ext.isEmpty ? id : '$id.$ext';
      final path = p.join(vaultPath, spaceId, 'drive', diskName);
      try {
        await fs.file(path).writeAsBytes(ef.bytes);
        meta[id] = {
          'name': ef.name,
          'created': ef.createdAt.toIso8601String(),
        };
        index[id] = path;
        result.add(DriveFile(
          id: id,
          name: ef.name,
          sizeBytes: ef.bytes.length,
          createdAt: ef.createdAt,
        ));
      } catch (e) {
        debugPrint('Failed to write imported file $id: $e');
      }
    }

    await _writeMeta(spaceId, meta);
    return result;
  }
}
