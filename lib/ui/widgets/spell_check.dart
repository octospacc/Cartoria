import 'package:flutter/material.dart';
import 'package:universal_spell_check/universal_spell_check.dart';

/// Shared [SpellCheckConfiguration] for every natural-language text field
/// in the composer flow (post body, post title, post description, and the
/// full-screen editor).
///
/// Backed by `universal_spell_check`, because Flutter's built-in
/// [DefaultSpellCheckService] only works on Android and iOS — macOS,
/// Windows and Linux get no spell check at all (flutter/flutter#40682).
/// The package uses the native system checker on each desktop platform
/// (NSSpellChecker on macOS, ISpellChecker on Windows, Enchant-2 on
/// Linux) and delegates to Flutter's service on mobile.
///
/// The web `NativeTextField` does not use this constant — it sets
/// `spellcheck = true` directly on the underlying DOM `<textarea>` in
/// `native_text_field_web.dart`.
final SpellCheckConfiguration kSpellCheckConfig =
    UniversalSpellCheck.configuration();

/// Context menu builder that surfaces spell-check suggestions in the
/// right-click / long-press menu. Use wherever [kSpellCheckConfig] is
/// applied so suggestions are reachable on desktop and web.
Widget spellCheckContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) =>
    UniversalSpellCheck.contextMenuBuilder(context, editableTextState);