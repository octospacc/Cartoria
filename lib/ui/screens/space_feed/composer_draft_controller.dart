import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/composer_draft.dart';
import '../../../data/store.dart';

/// Owns the debounce and lifecycle for a single composer's draft.
///
/// The composer builds a fresh [ComposerDraft] from its current state on
/// every change and calls [scheduleSave]. The controller stores it as
/// [pendingDraft], cancels any prior timer, and sets a new one. When
/// the timer fires (500 ms after the last change), the draft is flushed
/// to the store. Empty drafts are deleted rather than saved.
///
/// External resets (user taps "Reset") call [clear], which cancels any
/// pending save and deletes the draft from the store. Successful submits
/// also call [clear] (usually from the parent after post creation).
class ComposerDraftController extends ChangeNotifier {
  final VaultStore store;
  final String fieldKey;

  ComposerDraft? _pendingDraft;
  ComposerDraft? _restoredDraft;
  bool _hasRestoredDraft = false;
  DateTime? _lastSavedAt;
  Timer? _saveDebounce;

  ComposerDraftController({required this.store, required this.fieldKey});

  bool get hasRestoredDraft => _hasRestoredDraft;
  DateTime? get restoredDraftSavedAt => _restoredDraft?.savedAt;
  DateTime? get lastSavedAt => _lastSavedAt;

  /// Attempts to load a draft from the store. On success, marks the
  /// state as "restored" — callers use [hasRestoredDraft] to decide
  /// whether to show a "Unsaved draft from …" banner.
  Future<ComposerDraft?> loadRestored() async {
    final draft = await store.loadComposerDraft(fieldKey);
    if (draft != null && !draft.isEmpty) {
      _restoredDraft = draft;
      _hasRestoredDraft = true;
      _lastSavedAt = draft.savedAt;
      notifyListeners();
      return draft;
    }
    return null;
  }

  /// Schedules a debounced save with the current draft snapshot. The
  /// caller builds the draft eagerly, so disposal-time flushes don't
  /// need to re-read from controllers that may already be disposed.
  void scheduleSave(ComposerDraft draft) {
    _pendingDraft = draft;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    final draft = _pendingDraft;
    _pendingDraft = null;
    if (draft == null) return;
    try {
      if (draft.isEmpty) {
        await store.deleteComposerDraft(fieldKey);
        _lastSavedAt = null;
      } else {
        await store.saveComposerDraft(draft);
        _lastSavedAt = draft.savedAt;
      }
    } catch (e) {
      debugPrint('Draft save failed for $fieldKey: $e');
    }
  }

  /// Explicitly discards the draft and any pending save.
  Future<void> clear() async {
    _saveDebounce?.cancel();
    _pendingDraft = null;
    _hasRestoredDraft = false;
    _restoredDraft = null;
    _lastSavedAt = null;
    try {
      await store.deleteComposerDraft(fieldKey);
    } catch (e) {
      debugPrint('Draft delete failed for $fieldKey: $e');
    }
    notifyListeners();
  }

  /// Hides the "restored" banner without deleting the draft. Used when
  /// the user acknowledges the banner but keeps editing.
  void dismissBanner() {
    if (!_hasRestoredDraft) return;
    _hasRestoredDraft = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    final draft = _pendingDraft;
    _pendingDraft = null;
    if (draft != null) {
      // Fire-and-forget so the save lands even as the widget tears down.
      if (draft.isEmpty) {
        store.deleteComposerDraft(fieldKey);
      } else {
        store.saveComposerDraft(draft);
      }
    }
    super.dispose();
  }
}