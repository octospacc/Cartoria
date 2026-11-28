import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../l10n/l10n.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/rich_text_editor.dart';

class FullScreenTextEditor extends StatefulWidget {
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

  @override
  State<FullScreenTextEditor> createState() => _FullScreenTextEditorState();
}

class _FullScreenTextEditorState extends State<FullScreenTextEditor> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyEsc);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyEsc);
    super.dispose();
  }

  /// Runs before the focus tree — flutter_quill installs a
  /// `SingleActivator(escape)` shortcut for `HideSelectionToolbarIntent`
  /// that consumes ESC before any ancestor `Focus.onKeyEvent` fires.
  /// Early key handlers bypass that layer entirely.
  KeyEventResult _handleEarlyEsc(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (!mounted) return KeyEventResult.ignored;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return KeyEventResult.ignored;
    Navigator.of(context).maybePop();
    return KeyEventResult.handled;
  }

  Future<void> _insertEmoji() async {
    final emoji = await pickEmoji(context);
    if (emoji == null || !mounted) return;
    final sel = widget.controller.selection;
    final index =
        sel.isValid ? sel.start : widget.controller.document.length - 1;
    widget.controller.document.insert(index, emoji);
    widget.controller.updateSelection(
      TextSelection.collapsed(offset: index + emoji.length),
      quill.ChangeSource.local,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title ?? l.fullScreenEditorDefaultTitle,
                style: theme.textTheme.titleMedium),
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final text = widget.controller.document.toPlainText();
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
            onPressed: _insertEmoji,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: RichTextEditor(
            controller: widget.controller,
            hintText: widget.hintText,
            expands: true,
          ),
        ),
      ),
    );
  }
}