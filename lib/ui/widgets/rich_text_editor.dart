import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../l10n/l10n.dart';

class RichTextEditor extends StatefulWidget {
  final quill.QuillController controller;
  final String? hintText;
  final bool expands;
  final bool showToolbar;

  /// Minimum editor height in pixels when [expands] is false. The
  /// editor auto-grows from this up to [maxHeight].
  final double minHeight;

  /// Maximum editor height in pixels when [expands] is false. Past
  /// this, the editor scrolls internally. Null means unbounded.
  final double? maxHeight;

  final FocusNode? focusNode;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.hintText,
    this.expands = false,
    this.showToolbar = true,
    this.minHeight = 120,
    this.maxHeight,
    this.focusNode,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.expands ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.showToolbar) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FormatButton(
                    icon: Icons.format_bold,
                    tooltip: l.richEditorBold,
                    controller: widget.controller,
                    attribute: quill.Attribute.bold,
                  ),
                  _FormatButton(
                    icon: Icons.format_italic,
                    tooltip: l.richEditorItalic,
                    controller: widget.controller,
                    attribute: quill.Attribute.italic,
                  ),
                  _FormatButton(
                    icon: Icons.format_underline,
                    tooltip: l.richEditorUnderline,
                    controller: widget.controller,
                    attribute: quill.Attribute.underline,
                  ),
                  _FormatButton(
                    icon: Icons.format_strikethrough,
                    tooltip: l.richEditorStrikethrough,
                    controller: widget.controller,
                    attribute: quill.Attribute.strikeThrough,
                  ),
                  _FormatButton(
                    icon: Icons.code,
                    tooltip: l.richEditorInlineCode,
                    controller: widget.controller,
                    attribute: quill.Attribute.inlineCode,
                  ),
                  const SizedBox(width: 4),
                  const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                  IconButton(
                    icon: const Icon(Icons.format_clear, size: 18),
                    tooltip: l.richEditorClearFormatting,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _clearFormatting(widget.controller),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (widget.expands)
          Expanded(
            child: quill.QuillEditor.basic(
              controller: widget.controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: quill.QuillEditorConfig(
                placeholder: widget.hintText,
                expands: true,
                scrollable: true,
                padding: EdgeInsets.zero,
                autoFocus: false,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minHeight,
              maxHeight: widget.maxHeight ?? double.infinity,
            ),
            child: quill.QuillEditor.basic(
              controller: widget.controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: quill.QuillEditorConfig(
                placeholder: widget.hintText,
                expands: false,
                scrollable: true,
                padding: EdgeInsets.zero,
                autoFocus: false,
              ),
            ),
          ),
      ],
    );
  }

  static void _clearFormatting(quill.QuillController ctrl) {
    final sel = ctrl.selection;
    if (!sel.isValid) return;
    for (final attr in [
      quill.Attribute.bold,
      quill.Attribute.italic,
      quill.Attribute.underline,
      quill.Attribute.strikeThrough,
      quill.Attribute.inlineCode,
    ]) {
      ctrl.formatSelection(quill.Attribute.clone(attr, null));
    }
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final quill.QuillController controller;
  final quill.Attribute attribute;

  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.controller,
    required this.attribute,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final style = controller.getSelectionStyle();
        final active = style.attributes.containsKey(attribute.key);
        return IconButton(
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: active ? Theme.of(context).colorScheme.primary : null,
          onPressed: () {
            if (active) {
              controller.formatSelection(
                quill.Attribute.clone(attribute, null),
              );
            } else {
              controller.formatSelection(attribute);
            }
          },
        );
      },
    );
  }
}