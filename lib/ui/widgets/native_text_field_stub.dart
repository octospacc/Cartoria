import 'package:flutter/material.dart';

import 'spell_check.dart';

class NativeTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final TextStyle? style;
  final bool expands;

  /// Ignored on non-web. ESC is handled by `CallbackShortcuts` in the
  /// full-screen editor. The parameter exists for API parity with the
  /// web implementation.
  final VoidCallback? onEscape;

  const NativeTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.minLines = 1,
    this.maxLines = 6,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.expands = false,
    this.onEscape,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      expands: expands,
      minLines: expands ? null : minLines,
      maxLines: expands ? null : maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: style,
      spellCheckConfiguration: kSpellCheckConfig,
      contextMenuBuilder: spellCheckContextMenuBuilder,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}