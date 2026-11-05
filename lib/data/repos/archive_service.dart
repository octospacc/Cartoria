import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/fs_walk.dart';
import '../../util/html_utils.dart';
import '../models.dart';
import '../space_archive.dart';
import 'post_repo.dart';

/// Zips a whole space directory (or extracts one from a zip).
///
/// Imports are id-preserving where possible. If the target id already
/// exists on disk, the incoming space is given a fresh UUID and its
/// `space.html` frontmatter is rewritten to match. Reply parents that
/// pointed at the old id are *not* rewritten — matches the pre-refactor
/// behavior.
class ArchiveService {
  final FileSystem fs;
  final String vaultPath;

  const ArchiveService({required this.fs, required this.vaultPath});

  Future<Uint8List> exportSpace(String spaceId) async {
    final archive = Archive();
    final dirPath = p.join(vaultPath, spaceId);
    final files = await walkFiles(fs.directory(dirPath));
    for (final f in files) {
      try {
        final rel = p.relative(f.path, from: dirPath);
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile('$spaceId/$rel', bytes.length, bytes));
      } catch (e) {
        debugPrint('Skipping unreadable file ${f.path}: $e');
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Extracts a space zip and returns the id it was written under.
  /// The caller is responsible for reloading its cache.
  Future<String> importSpace(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // Locate the shallowest `space.html` in the zip — that marks the space
    // root. Zips created by this app contain exactly one; hand-edited ones
    // might contain nested copies, and we pick the shortest path.
    ArchiveFile? spaceFile;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == 'space.html' || f.name.endsWith('/space.html')) {
        if (spaceFile == null || f.name.length < spaceFile.name.length) {
          spaceFile = f;
        }
      }
    }
    if (spaceFile == null) {
      throw const FormatException('Zip does not contain space.html');
    }

    final content = utf8.decode(spaceFile.content as List<int>);
    final meta = parseFrontmatterMeta(content);
    var newId = (meta['id'] as String?) ?? const Uuid().v7();
    final conflict = await fs.directory(p.join(vaultPath, newId)).exists();
    if (conflict) newId = const Uuid().v7();

    final spaceDir = p.dirname(spaceFile.name);
    final prefix = (spaceDir.isEmpty || spaceDir == '.') ? '' : '$spaceDir/';
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith(prefix)) continue;
      final rel = f.name.substring(prefix.length);
      if (rel.isEmpty) continue;

      // Normalise legacy `posts/` entries into `entries/` on the way in,
      // so a vault that imports an old zip ends up with the current
      // layout. The content is identical; only the directory name differs.
      final normalisedRel = rel.startsWith('posts/')
          ? 'entries/${rel.substring('posts/'.length)}'
          : rel;

      final dest = p.join(vaultPath, newId, normalisedRel);
      await fs.directory(p.dirname(dest)).create(recursive: true);
      await fs
          .file(dest)
          .writeAsBytes(Uint8List.fromList(f.content as List<int>));
    }

    if (conflict) {
      final updated = {...meta, 'id': newId};
      final body = bodyAfterFrontmatter(content);
      await fs
          .file(p.join(vaultPath, newId, 'space.html'))
          .writeAsString(makeDocument(updated, body));
    }

    return newId;
  }

  /// Decodes a space zip into memory without touching the filesystem.
  /// Consumed by [VaultStore.importSpaceZipIntoExistingSpace].
  Future<ExtractedSpace> readSpaceArchive(Uint8List zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? spaceFile;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == 'space.html' || f.name.endsWith('/space.html')) {
        if (spaceFile == null || f.name.length < spaceFile.name.length) {
          spaceFile = f;
        }
      }
    }
    if (spaceFile == null) {
      throw const FormatException('Zip does not contain space.html');
    }

    final content = utf8.decode(spaceFile.content as List<int>);
    final meta = parseFrontmatterMeta(content);
    final name = (meta['name'] as String?) ?? 'Imported space';
    final icon = (meta['icon'] as String?) ?? '📓';
    final createdAtStr = meta['created'] as String?;
    final createdAt = createdAtStr != null
        ? DateTime.parse(createdAtStr)
        : DateTime.now().toUtc();

    final spaceDir = p.dirname(spaceFile.name);
    final prefix = (spaceDir.isEmpty || spaceDir == '.') ? '' : '$spaceDir/';

    // drive_meta.json (optional)
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

    // Entries. Accept both `entries/` (current) and `posts/` (legacy zips)
    // so imports from pre-rename exports still work.
    final posts = <Post>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (!f.name.endsWith('.html')) continue;
      final rel = f.name.startsWith(prefix)
          ? f.name.substring(prefix.length)
          : f.name;
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

    // Drive files
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
    );
  }
}