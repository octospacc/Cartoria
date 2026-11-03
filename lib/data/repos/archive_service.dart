import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/fs_walk.dart';
import '../../util/html_utils.dart';

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
      final dest = p.join(vaultPath, newId, rel);
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
}