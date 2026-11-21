import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../l10n/l10n.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/rich_text_editor.dart';

class FullScreenTextEditor extends StatelessWidget {
  final quill.QuillController controller;
  final String? title;
  final String? hintText;

  const FullScreenTextEditor({
    super.key,
    required this.controller,
    this.title,
    this.hintText,
  });

  static Future<void> show(
    BuildContext context, {
    required quill.QuillController controller,
    String? title,
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

  Future<void> _insertEmoji(BuildContext context) async {
    final emoji = await pickEmoji(context);
    if (emoji == null) return;
    final sel = controller.selection;
    final index = sel.isValid ? sel.start : controller.document.length - 1;
    controller.document.insert(index, emoji);
    controller.updateSelection(
      TextSelection.collapsed(offset: index + emoji.length),
      quill.ChangeSource.local,
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
                  final text = controller.document.toPlainText();
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
              onPressed: () => _insertEmoji(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: RichTextEditor(
              controller: controller,
              hintText: hintText,
              expands: true,
            ),
          ),
        ),
      ),
    );
  }
}