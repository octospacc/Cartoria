import 'dart:convert';
import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../sync/offloaded_store.dart';
import '../space_archive.dart';

/// Stores opaque file blobs under `drive/<id>.<ext>` (or `drive/<id>` for
/// extensionless names) and their metadata under `drive_meta.json`.
///
/// Offloaded files exist in `drive_meta.json` and in the remote git repo,
/// but not on local disk. `OffloadedStore` records their `remoteSha` and
/// `size`. [list] reports them with the recorded size; [readBytes] fetches
/// them via the injected [onFetchBytes] callback.
class DriveRepository {
  final FileSystem fs;
  final String vaultPath;

  /// `spaceId` → (`fileId` → full on-disk path). Rebuilt lazily; cleared
  /// by [clearCache].
  final Map<String, Map<String, String>> _pathCache = {};

  OffloadedStore? offloadedStore;

  /// Async fetcher supplied by the store, resolving bytes for offloaded
  /// files via the sync provider. Null when no sync config is configured.
  Future<Uint8List> Function(String spaceId, String fileId)? onFetchBytes;

  DriveRepository({required this.fs, required this.vaultPath});

  // ── Public API ─────────────────────────────────────────────────────────

  Future<List<DriveFile>> list(String spaceId) async {
    final meta = await _readMeta(spaceId);
    if (meta.isEmpty) return const [];

    final index = await _driveIndex(spaceId);
    final offloaded = await offloadedStore?.load(spaceId) ?? const {};
    final result = <DriveFile>[];

    for (final entry in meta.entries) {
      final id = entry.key;
      final m = entry.value;
      try {
        final off = offloaded[id];
        if (off != null) {
          result.add(DriveFile(
            id: id,
            name: (m['name'] as String?) ?? id,
            sizeBytes: off.size,
            createdAt: DateTime.parse(m['created'] as String),
          ));
          continue;
        }
        final path = index[id];
        if (path == null) {
          // In meta but no blob and not offloaded — a dangling reference
          // from a partial import. Surface it so the user can re-import
          // the full zip to fill it back in.
          result.add(DriveFile(
            id: id,
            name: (m['name'] as String?) ?? id,
            sizeBytes: 0,
            createdAt: DateTime.parse(m['created'] as String),
            isMissing: true,
          ));
          continue;
        }
        final stat = await fs.file(path).stat();
        result.add(DriveFile(
          id: id,
          name: (m['name'] as String?) ?? id,
          sizeBytes: stat.size,
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
    if (path != null) {
      final f = fs.file(path);
      if (await f.exists()) return f.readAsBytes();
    }

    final off = await offloadedStore?.get(spaceId, fileId);
    if (off != null) {
      final fetcher = onFetchBytes;
      if (fetcher == null) {
        throw StateError(
            'File $fileId is offloaded and no fetcher is configured.');
      }
      return fetcher(spaceId, fileId);
    }

    throw StateError('Drive file $fileId not found in space $spaceId');
  }

  Future<void> delete(String spaceId, String fileId) async {
    final index = await _driveIndex(spaceId);
    final path = index.remove(fileId);
    if (path != null) {
      final f = fs.file(path);
      if (await f.exists()) await f.delete();
    }

    final store = offloadedStore;
    if (store != null) {
      final info = await store.load(spaceId);
      if (info.remove(fileId) != null) {
        await store.save(spaceId, info);
      }
    }

    final meta = await _readMeta(spaceId);
    meta.remove(fileId);
    await _writeMeta(spaceId, meta);
  }

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

    final store = offloadedStore;
    if (store != null) {
      final info = await store.load(spaceId);
      var changed = false;
      for (final id in fileIds) {
        if (info.remove(id) != null) changed = true;
      }
      if (changed) await store.save(spaceId, info);
    }

    final meta = await _readMeta(spaceId);
    for (final id in fileIds) {
      meta.remove(id);
    }
    await _writeMeta(spaceId, meta);
  }

  /// Writes multiple pre-read files with one metadata write.
  Future<List<DriveFile>> importExistingFiles({
    required String spaceId,
    required Map<String, ExtractedFile> files,
    required Map<String, Map<String, dynamic>> driveMeta,
    required Set<String> existingIds,
  }) async {
    if (files.isEmpty && driveMeta.isEmpty) return const [];
    await fs
        .directory(p.join(vaultPath, spaceId, 'drive'))
        .create(recursive: true);

    final meta = await _readMeta(spaceId);

    // Add all meta entries from the zip. This preserves references to
    // files that weren't in the zip (offloaded on the source or excluded
    // by the export mode). Files already in the target keep their
    // existing meta (putIfAbsent), so re-imports don't overwrite.
    for (final entry in driveMeta.entries) {
      meta.putIfAbsent(entry.key, () => entry.value);
    }

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

  /// Removes the on-disk copy and records the file as offloaded.
  Future<void> offloadFile(
    String spaceId,
    String fileId, {
    required String remoteSha,
    required int size,
  }) async {
    final index = await _driveIndex(spaceId);
    final path = index.remove(fileId);
    if (path != null) {
      final f = fs.file(path);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (e) {
          debugPrint('Failed to delete on-disk copy of $fileId: $e');
        }
      }
    }

    final store = offloadedStore;
    if (store == null) return;
    final info = await store.load(spaceId);
    info[fileId] = OffloadedFileInfo(remoteSha: remoteSha, size: size);
    await store.save(spaceId, info);
  }

  /// Removes the offloaded marker. Does not download the file.
  Future<void> unoffloadFile(String spaceId, String fileId) async {
    final store = offloadedStore;
    if (store == null) return;
    final info = await store.load(spaceId);
    if (info.remove(fileId) != null) {
      await store.save(spaceId, info);
    }
  }

  /// Writes [bytes] to disk under the correct filename and clears the
  /// offloaded marker. Also updates the path cache so subsequent
  /// [readBytes] calls find the file without rebuilding the index.
  Future<void> restoreFile(
    String spaceId,
    String fileId,
    Uint8List bytes,
  ) async {
    final meta = await _readMeta(spaceId);
    final entry = meta[fileId];
    if (entry == null) {
      throw StateError('File $fileId not in drive_meta.json');
    }
    final name = (entry['name'] as String?) ?? fileId;
    final ext = _sanitizedExtension(name);
    final diskName = ext.isEmpty ? fileId : '$fileId.$ext';
    final path = p.join(vaultPath, spaceId, 'drive', diskName);

    await fs
        .directory(p.join(vaultPath, spaceId, 'drive'))
        .create(recursive: true);
    await fs.file(path).writeAsBytes(bytes);

    final index = await _driveIndex(spaceId);
    index[fileId] = path;

    await unoffloadFile(spaceId, fileId);
  }

  /// Writes bytes into the slot for an existing file that is currently
  /// missing (in `drive_meta.json` but no blob on disk, not offloaded).
  /// Preserves the file's id and creation time; updates the display name
  /// to [name] so the on-disk extension matches the picked file's content.
  Future<DriveFile> restoreMissingFile({
    required String spaceId,
    required String fileId,
    required Uint8List bytes,
    required String name,
  }) async {
    final meta = await _readMeta(spaceId);
    final existing = meta[fileId];
    if (existing == null) {
      throw StateError('File $fileId not in drive_meta.json');
    }
    final createdAt = DateTime.parse(existing['created'] as String);

    // Update meta first — this is the source of truth for what exists.
    meta[fileId] = {
      'name': name,
      'created': createdAt.toIso8601String(),
    };
    await _writeMeta(spaceId, meta);

    // Write the blob under the new extension.
    final ext = _sanitizedExtension(name);
    final diskName = ext.isEmpty ? fileId : '$fileId.$ext';
    final path = p.join(vaultPath, spaceId, 'drive', diskName);
    await fs
        .directory(p.join(vaultPath, spaceId, 'drive'))
        .create(recursive: true);
    await fs.file(path).writeAsBytes(bytes);

    // Update the path cache so subsequent reads find the file.
    final index = await _driveIndex(spaceId);
    index[fileId] = path;

    return DriveFile(
      id: fileId,
      name: name,
      sizeBytes: bytes.length,
      createdAt: createdAt,
    );
  }

  /// Drops the path cache for all spaces.
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
            }
          }
        }
      }

      out[id] = chosen.path;
    }

    return out;
  }

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
    await fs
        .file(p.join(vaultPath, spaceId, 'drive_meta.json'))
        .writeAsString(_prettyJson(meta));
  }

  String _prettyJson(Object? value) =>
      '${const JsonEncoder.withIndent('  ').convert(value)}\n';
}
