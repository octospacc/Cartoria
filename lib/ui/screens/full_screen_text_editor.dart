import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/emoji_picker_sheet.dart';
import '../widgets/native_text_field.dart';
import '../../l10n/l10n.dart';

const bool _kUseNativeTextField = true;

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

    void close() {
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true) {
        Navigator.of(context).maybePop();
      }
    }

    return Focus(
      // Request focus on mount so that when no text field has focus,
      // this node is the primary and its onKeyEvent catches ESC.
      autofocus: true,
      // The inner TextField also has autofocus: true. It's deeper in
      // the tree, so its focus request runs later and wins. This outer
      // Focus only holds primary in the gap before the field mounts,
      // and after the user taps a non-focusable area.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
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
                  final words = trimmed.isEmpty
                      ? 0
                      : trimmed.split(RegExp(r'\s+')).length;
                  final chars = text.runes.length;
                  return Text(
                    context.l10n.fullScreenEditorWordCount(words, chars),
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
              tooltip: context.l10n.fullScreenEditorEmojiTooltip,
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
                    onEscape: close,
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
      ),
    );
  }
}