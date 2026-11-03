import 'dart:convert';
import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models.dart';

/// Stores opaque file blobs under `drive/<id>` and their metadata under
/// `drive_meta.json` (a flat `{id: {name, created}}` map).
///
/// Metadata is read+rewritten on every mutation — fine for the scale of a
/// personal vault, and it keeps the on-disk format a plain JSON file that
/// survives sync / diff tools.
class DriveRepository {
  final FileSystem fs;
  final String vaultPath;

  const DriveRepository({required this.fs, required this.vaultPath});

  Future<List<DriveFile>> list(String spaceId) async {
    final meta = await _readMeta(spaceId);
    final result = <DriveFile>[];
    for (final entry in meta.entries) {
      final id = entry.key;
      final m = entry.value;
      final file = fs.file(p.join(vaultPath, spaceId, 'drive', id));
      if (!await file.exists()) continue;
      try {
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
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  Future<DriveFile> addBytes({
    required String spaceId,
    required Uint8List bytes,
    required String name,
  }) async {
    final id = const Uuid().v7();
    final now = DateTime.now().toUtc();
    await fs
        .directory(p.join(vaultPath, spaceId, 'drive'))
        .create(recursive: true);
    await fs.file(p.join(vaultPath, spaceId, 'drive', id)).writeAsBytes(bytes);
    final meta = await _readMeta(spaceId);
    meta[id] = {'name': name, 'created': now.toIso8601String()};
    await _writeMeta(spaceId, meta);
    return DriveFile(
      id: id,
      name: name,
      sizeBytes: bytes.length,
      createdAt: now,
    );
  }

  Future<Uint8List> readBytes(String spaceId, String fileId) {
    return fs.file(p.join(vaultPath, spaceId, 'drive', fileId)).readAsBytes();
  }

  Future<void> delete(String spaceId, String fileId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'drive', fileId));
    if (await f.exists()) await f.delete();
    final meta = await _readMeta(spaceId);
    meta.remove(fileId);
    await _writeMeta(spaceId, meta);
  }

  // ── drive_meta.json ────────────────────────────────────────────────────

  Future<Map<String, Map<String, dynamic>>> _readMeta(String spaceId) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'drive_meta.json'));
    if (!await f.exists()) return {};
    final raw = jsonDecode(await f.readAsString()) as Map;
    return raw.map((k, v) =>
        MapEntry(k as String, (v as Map).cast<String, dynamic>()));
  }

  Future<void> _writeMeta(
      String spaceId, Map<String, Map<String, dynamic>> meta) async {
    await fs
        .file(p.join(vaultPath, spaceId, 'drive_meta.json'))
        .writeAsString(jsonEncode(meta));
  }
}