import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/fs_walk.dart';
import '../../util/html_utils.dart';
import '../../util/json_format.dart';
import '../models.dart';
import '../space_archive.dart';
import 'post_repo.dart';

/// Zips a whole space directory (or extracts one from a zip).
///
/// Imports are id-preserving where possible. If the target id already
/// exists on disk, the incoming space is given a fresh UUID.
///
/// Both `space.json` (current) and `space.html` (legacy zips) are
/// recognised. On extraction the space metadata is always written as
/// `space.json`, regardless of the source format. Legacy `posts/`
/// directories are normalised to `entries/` on the way in.
class ArchiveService {
  final FileSystem fs;
  final String vaultPath;

  const ArchiveService({required this.fs, required this.vaultPath});

  Future<Uint8List> exportSpace(
    String spaceId, {
    ExportMediaMode mode = ExportMediaMode.onDiskOnly,
    Map<String, Uint8List> offloadedBlobs = const {},
  }) async {
    final archive = Archive();
    final dirPath = p.join(vaultPath, spaceId);
    final files = await walkFiles(fs.directory(dirPath));

    final onDiskDriveIds = <String>{};

    for (final f in files) {
      try {
        final rel = p.relative(f.path, from: dirPath);

        // Skip drive blobs for lite export.
        if (mode == ExportMediaMode.noMedia && rel.startsWith('drive/')) {
          continue;
        }

        if (rel.startsWith('drive/')) {
          final base = p.basename(f.path);
          final dot = base.indexOf('.');
          onDiskDriveIds.add(dot < 0 ? base : base.substring(0, dot));
        }

        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile('$spaceId/$rel', bytes.length, bytes));
      } catch (e) {
        debugPrint('Skipping unreadable file ${f.path}: $e');
      }
    }

    // Add offloaded blobs provided by the caller. Only meaningful for
    // ExportMediaMode.full — the caller fetches them from the remote.
    if (mode == ExportMediaMode.full && offloadedBlobs.isNotEmpty) {
      final metaFile = fs.file(p.join(dirPath, 'drive_meta.json'));
      var meta = <String, dynamic>{};
      if (await metaFile.exists()) {
        try {
          meta = (jsonDecode(await metaFile.readAsString()) as Map)
              .cast<String, dynamic>();
        } catch (_) {}
      }

      for (final entry in offloadedBlobs.entries) {
        final id = entry.key;
        if (onDiskDriveIds.contains(id)) continue;
        final bytes = entry.value;
        final m = meta[id];
        final name = (m is Map ? m['name'] as String? : null) ?? id;
        final dot = name.lastIndexOf('.');
        final ext = (dot < 0 || dot == 0)
            ? ''
            : name
                .substring(dot + 1)
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]'), '');
        final diskName = ext.isEmpty ? id : '$id.$ext';
        archive.addFile(
            ArchiveFile('$spaceId/drive/$diskName', bytes.length, bytes));
      }
    }

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Extracts a space zip and returns the id it was written under.
  /// The caller is responsible for reloading its cache.
  Future<String> importSpace(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final (spaceFile, spaceFilename) = _findSpaceMetadata(archive);
    if (spaceFile == null) {
      throw const FormatException(
          'Zip does not contain space.json or space.html');
    }

    final meta = _parseSpaceMeta(spaceFile, spaceFilename!);
    var newId = (meta['id'] as String?) ?? const Uuid().v7();
    final conflict = await fs.directory(p.join(vaultPath, newId)).exists();
    if (conflict) newId = const Uuid().v7();

    final spaceDir = p.dirname(spaceFile.name);
    final prefix = (spaceDir.isEmpty || spaceDir == '.') ? '' : '$spaceDir/';

    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith(prefix)) continue;
      final rel = f.name.substring(prefix.length);
      if (rel.isEmpty) continue;

      // The space metadata is written separately, below, in JSON form.
      if (rel == 'space.json' || rel == 'space.html') continue;

      // Normalise legacy posts/ → entries/ on the way in.
      final normalisedRel = rel.startsWith('posts/')
          ? 'entries/${rel.substring('posts/'.length)}'
          : rel;

      final dest = p.join(vaultPath, newId, normalisedRel);
      await fs.directory(p.dirname(dest)).create(recursive: true);
      await fs
          .file(dest)
          .writeAsBytes(Uint8List.fromList(f.content as List<int>));
    }

    // Always write space.json, with the resolved id.
    await fs
        .file(p.join(vaultPath, newId, 'space.json'))
        .writeAsString(prettyJson({...meta, 'id': newId}));

    return newId;
  }

  /// Decodes a space zip into memory without touching the filesystem.
  /// Consumed by [VaultStore.importSpaceZipIntoExistingSpace].
  Future<ExtractedSpace> readSpaceArchive(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final (spaceFile, spaceFilename) = _findSpaceMetadata(archive);
    if (spaceFile == null) {
      throw const FormatException(
          'Zip does not contain space.json or space.html');
    }

    final meta = _parseSpaceMeta(spaceFile, spaceFilename!);
    final name = (meta['name'] as String?) ?? 'Imported space';
    final icon = (meta['icon'] as String?) ?? '📓';
    final createdAtStr = meta['created'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.parse(createdAtStr)
        : DateTime.now().toUtc();

    final spaceDir = p.dirname(spaceFile.name);
    final prefix = (spaceDir.isEmpty || spaceDir == '.') ? '' : '$spaceDir/';

    // drive_meta.json — read as-is. If it references files that aren't in
    // the zip (offloaded on source, or excluded during export), those
    // entries are still preserved so the target space knows what's missing.
    var driveMeta = <String, Map<String, dynamic>>{};
    for (final f in archive.files) {
      if (!f.isFile || f.name != '${prefix}drive_meta.json') continue;
      try {
        final raw = jsonDecode(utf8.decode(f.content as List<int>)) as Map;
        driveMeta = raw.map((k, v) =>
            MapEntry(k as String, (v as Map).cast<String, dynamic>()));
      } catch (_) {}
      break;
    }

    // Entries — full parse, no reference trimming.
    final posts = <Post>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (!f.name.endsWith('.html')) continue;
      final rel =
          f.name.startsWith(prefix) ? f.name.substring(prefix.length) : f.name;
      if (!rel.startsWith('entries/') && !rel.startsWith('posts/')) continue;
      try {
        posts.add(PostRepository.parseContent(
          f.name,
          utf8.decode(f.content as List<int>),
        ));
      } catch (e) {
        debugPrint('Skipping malformed entry ${f.name}: $e');
      }
    }
    posts.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Drive blobs present in the zip.
    final files = <String, ExtractedFile>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (!f.name.startsWith('${prefix}drive/')) continue;
      final base = f.name.substring('${prefix}drive/'.length);
      if (base.isEmpty || base.contains('/')) continue;
      final dot = base.indexOf('.');
      final id = dot < 0 ? base : base.substring(0, dot);
      final m = driveMeta[id];
      final fname = (m?['name'] as String?) ?? base;
      final fcreated = m?['created'] as String?;
      files[id] = ExtractedFile(
        name: fname,
        bytes: Uint8List.fromList(f.content as List<int>),
        createdAt: fcreated != null ? DateTime.parse(fcreated) : createdAt,
      );
    }

    return ExtractedSpace(
      name: name,
      icon: icon,
      createdAt: createdAt,
      posts: posts,
      files: files,
      driveMeta: driveMeta,
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────

  /// Locates the space metadata file in the archive.
  ///
  /// Prefers `space.json`; falls back to `space.html` for zips created
  /// before the JSON migration. When multiple candidates exist, the
  /// shallowest one wins (matches the previous behaviour).
  (ArchiveFile?, String?) _findSpaceMetadata(Archive archive) {
    ArchiveFile? jsonFile;
    ArchiveFile? htmlFile;

    for (final f in archive.files) {
      if (!f.isFile) continue;
      final isJson = f.name == 'space.json' || f.name.endsWith('/space.json');
      final isHtml = f.name == 'space.html' || f.name.endsWith('/space.html');
      if (isJson) {
        if (jsonFile == null || f.name.length < jsonFile.name.length) {
          jsonFile = f;
        }
      } else if (isHtml) {
        if (htmlFile == null || f.name.length < htmlFile.name.length) {
          htmlFile = f;
        }
      }
    }

    if (jsonFile != null) return (jsonFile, 'space.json');
    if (htmlFile != null) return (htmlFile, 'space.html');
    return (null, null);
  }

  /// Parses the metadata map from either format. Never returns null.
  Map<String, dynamic> _parseSpaceMeta(ArchiveFile f, String filename) {
    final raw = utf8.decode(f.content as List<int>);
    if (filename == 'space.json') {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('space.json must contain an object');
      }
      return decoded.cast<String, dynamic>();
    }
    return parseFrontmatterMeta(raw);
  }
}
