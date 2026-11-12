import 'package:flutter/material.dart';

import '../widgets/native_text_field.dart';
import '../widgets/emoji_picker_sheet.dart';

/// Flip to false to fall back to a regular TextField if NativeTextField
/// misbehaves on iOS Safari in this context. Provides a one-line revert
/// without touching the rest of the file.
const bool _kUseNativeTextField = true;

/// Full-screen text editing view.
///
/// Pushed from a composer (inline or sheet) when the user wants a
/// larger canvas. On iOS Safari, a bare Scaffold with a single
/// `TextField` avoids both bug-triggering contexts: no modal route
/// resize, no parent `SingleChildScrollView`. The field's own internal
/// scroll is the only scrollable, which is the case the underlying
/// Flutter `TextField` handles correctly.
///
/// The text is shared with the caller via [controller] — no snapshot /
/// revert semantics. Back arrow returns to the caller with whatever
/// text was last typed. Users who want to abandon a change can use the
/// field's own undo (three-finger tap on iOS, Ctrl+Z / Cmd+Z
/// elsewhere).
class FullScreenTextEditor extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String? hintText;

  const FullScreenTextEditor({
    super.key,
    required this.controller,
    this.title = 'Edit',
    this.hintText,
  });

  /// Pushes the editor as a full-screen modal route. Returns when the
  /// user dismisses it. The [controller] reflects whatever text was
  /// last typed.
  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    String title = 'Edit',
    String? hintText,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenTextEditor(
          controller: controller,
          title: title,
          hintText: hintText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final text = value.text;
                final trimmed = text.trim();
                final words =
                    trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
                // `runes.length` counts code points (one per visible
                // symbol for most emoji), which is closer to what users
                // expect than UTF-16 code units (`String.length`).
                final chars = text.runes.length;
                return Text(
                  '$words word${words == 1 ? "" : "s"} · '
                  '$chars char${chars == 1 ? "" : "s"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            tooltip: 'Emoji',
            onPressed: () => showEmojiPickerSheet(context, controller),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _kUseNativeTextField
              ? NativeTextField(
                  controller: controller,
                  autofocus: true,
                  expands: true,
                  hintText: hintText,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: theme.colorScheme.onSurface,
                  ),
                )
              : TextField(
                  controller: controller,
                  autofocus: true,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
        ),
      ),
    );
  }
}
