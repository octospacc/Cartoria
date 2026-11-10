import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'composer_draft.dart';

/// Persists composer drafts to `<app-support>/cartoria/drafts/`.
///
/// Deliberately outside the vault: drafts are per-device scratch state,
/// not published content. Syncing them to git would leak unfinished
/// thoughts into history and churn on every keystroke burst.
class ComposerDraftStore {
  const ComposerDraftStore();

  Future<Directory> _dir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'cartoria', 'drafts'));
    await dir.create(recursive: true);
    return dir;
  }

  String _slug(String fieldKey) =>
      fieldKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<File> _file(String fieldKey) async {
    final dir = await _dir();
    return File(p.join(dir.path, '${_slug(fieldKey)}.json'));
  }

  Future<ComposerDraft?> load(String fieldKey) async {
    try {
      final f = await _file(fieldKey);
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      return ComposerDraft.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ComposerDraft draft) async {
    try {
      final f = await _file(draft.fieldKey);
      await f.writeAsString(jsonEncode(draft.toJson()));
    } catch (_) {}
  }

  Future<void> delete(String fieldKey) async {
    try {
      final f = await _file(fieldKey);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}