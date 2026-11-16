import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_spell_check/universal_spell_check.dart';

/// Wraps a [SpellCheckService] with a per-locale debounce.
///
/// Flutter's [EditableText] calls the service on every keystroke with no
/// built-in debounce (flutter/flutter#152205). Native macOS
/// (`NSSpellChecker`) is fast per call, but the queued volume during
/// fast typing backs up the async scheduler and makes the composer feel
/// laggy.
///
/// This decorator coalesces keystrokes: only the final text of a typing
/// burst is checked, after [delay]. Stale intermediate results are
/// dropped by completing the previous completer with `null` rather than
/// letting it resolve late.
class _DebouncedSpellCheckService implements SpellCheckService {
  final SpellCheckService _inner;
  final Duration _delay;
  final Map<String, Timer> _timers = {};
  final Map<String, Completer<List<SuggestionSpan>?>> _pending = {};

  _DebouncedSpellCheckService({
    required SpellCheckService inner,
    Duration delay = const Duration(milliseconds: 200),
  })  : _inner = inner,
        _delay = delay;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) {
    final tag = locale.toLanguageTag();

    // Cancel the previous timer for this locale and resolve the stale
    // future with `null` — EditableText treats null as "no results",
    // which is correct for text it has already moved past.
    _timers.remove(tag)?.cancel();
    _pending.remove(tag)?.complete(null);

    final completer = Completer<List<SuggestionSpan>?>();
    _pending[tag] = completer;

    _timers[tag] = Timer(_delay, () async {
      _pending.remove(tag);
      try {
        final results =
            await _inner.fetchSpellCheckSuggestions(locale, text);
        if (!completer.isCompleted) completer.complete(results);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}

/// Spell-check configuration used by every prose field in the composer.
///
/// Keeps the native backend (`NSSpellChecker` on macOS) so every
/// language the OS supports — English, Italian, and the rest — works
/// out of the box. Debounces the per-keystroke calls, which is the
/// actual source of the composer lag.
final SpellCheckConfiguration kSpellCheckConfig = SpellCheckConfiguration(
  spellCheckService: _DebouncedSpellCheckService(
    inner: UniversalSpellCheckService.instance,
    delay: const Duration(milliseconds: 200),
  ),
  misspelledTextStyle: UniversalSpellCheck.misspelledTextStyle,
  spellCheckSuggestionsToolbarBuilder: spellCheckContextMenuBuilder,
);

/// Context-menu builder that surfaces suggestions on right-click
/// (desktop) or long-press (mobile).
Widget spellCheckContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  return UniversalSpellCheck.contextMenuBuilder(context, editableTextState);
}