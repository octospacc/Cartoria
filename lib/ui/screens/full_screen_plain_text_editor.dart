import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../widgets/emoji_picker_sheet.dart';

class FullScreenPlainTextEditor extends StatelessWidget {
  final TextEditingController controller;
  final String? title;
  final String? hintText;

  const FullScreenPlainTextEditor({
    super.key,
    required this.controller,
    this.title,
    this.hintText,
  });

  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    String? title,
    String? hintText,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenPlainTextEditor(
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
    final l = context.l10n;

    void close() {
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true) Navigator.of(context).maybePop();
    }

    return Focus(
      autofocus: true,
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
              Text(title ?? l.fullScreenEditorDefaultTitle,
                  style: theme.textTheme.titleMedium),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final text = controller.text;
                  final trimmed = text.trim();
                  final words = trimmed.isEmpty
                      ? 0
                      : trimmed.split(RegExp(r'\s+')).length;
                  final chars = text.runes.length;
                  return Text(
                    l.fullScreenEditorWordCount(words, chars),
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
              tooltip: l.composerEmojiTooltip,
              onPressed: () => showEmojiPickerSheet(context, controller),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
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