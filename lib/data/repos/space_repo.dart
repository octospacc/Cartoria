import 'package:fs_shim/fs_shim.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../util/html_utils.dart';
import '../models.dart';

/// Reads and writes space directories: `<vault>/<space-id>/space.html`
/// holds the frontmatter (id, name, icon, created) and a trivial body.
class SpaceRepository {
  final FileSystem fs;
  final String vaultPath;

  const SpaceRepository({required this.fs, required this.vaultPath});

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

  Future<Space?> _read(String id) async {
    final f = fs.file(p.join(vaultPath, id, 'space.html'));
    if (!await f.exists()) return null;
    final content = await f.readAsString();
    final meta = parseFrontmatterMeta(content);
    return Space(
      id: (meta['id'] as String?) ?? id,
      name: (meta['name'] as String?) ?? id,
      icon: (meta['icon'] as String?) ?? '📓',
      createdAt: DateTime.parse(meta['created'] as String),
    );
  }

  Future<Space> create({required String name, String icon = '📓'}) async {
    final id = const Uuid().v7();
    final now = DateTime.now().toUtc();
    final dir = p.join(vaultPath, id);
    await fs.directory(p.join(dir, 'posts')).create(recursive: true);
    await fs.directory(p.join(dir, 'drive')).create(recursive: true);
    await fs.file(p.join(dir, 'drive_meta.json')).writeAsString('{}');
    final meta = <String, dynamic>{
      'id': id,
      'name': name,
      'icon': icon,
      'created': now.toIso8601String(),
    };
    await fs
        .file(p.join(dir, 'space.html'))
        .writeAsString(makeDocument(meta, '<h1>${escapeHtml(name)}</h1>'));
    return Space(id: id, name: name, icon: icon, createdAt: now);
  }

  /// Rewrites `space.html` with new [name] and [icon], preserving the
  /// original `id` and `created` from disk. The body is regenerated to
  /// match the new name (the app never writes custom body content).
  Future<Space> update({
    required String spaceId,
    required String name,
    required String icon,
  }) async {
    final f = fs.file(p.join(vaultPath, spaceId, 'space.html'));
    if (!await f.exists()) {
      throw StateError('Space $spaceId not found');
    }
    final content = await f.readAsString();
    final oldMeta = parseFrontmatterMeta(content);
    final createdAt = DateTime.parse(oldMeta['created'] as String);

    final updatedMeta = <String, dynamic>{
      'id': spaceId,
      'name': name,
      'icon': icon,
      'created': createdAt.toIso8601String(),
    };
    await f.writeAsString(
      makeDocument(updatedMeta, '<h1>${escapeHtml(name)}</h1>'),
    );
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
}