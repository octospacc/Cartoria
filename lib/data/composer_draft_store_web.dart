import 'dart:convert';

import 'package:web/web.dart' as web;

import 'composer_draft.dart';

/// Persists composer drafts to `localStorage`.
///
/// The web has no persistent app-private filesystem; drafts are small
/// (a few KB each) and fit comfortably in localStorage. They survive
/// page reloads and browser restarts, but are cleared by "Clear site
/// data" — same profile as sync tokens and offloaded records.
class ComposerDraftStore {
  const ComposerDraftStore();

  static const _prefix = 'cartoria_draft_';

  Future<ComposerDraft?> load(String fieldKey) async {
    try {
      final raw = web.window.localStorage.getItem('$_prefix$fieldKey');
      if (raw == null || raw.isEmpty) return null;
      return ComposerDraft.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ComposerDraft draft) async {
    try {
      web.window.localStorage.setItem(
          '$_prefix${draft.fieldKey}', jsonEncode(draft.toJson()));
    } catch (_) {}
  }

  Future<void> delete(String fieldKey) async {
    try {
      web.window.localStorage.removeItem('$_prefix$fieldKey');
    } catch (_) {}
  }
}