import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../l10n/l10n.dart';

/// Pure rendering widget. **No keyboard handling.** ESC, save, navigation
/// etc. are container concerns, not editor concerns — a rich editor that
/// tries to intercept ESC conflicts with Quill's own internal Shortcuts
/// (flutter_quill installs `SingleActivator(escape)` for
/// HideSelectionToolbarIntent, and trying to beat it at the widget level
/// is a losing battle). Each call site owns its own ESC handling via
/// `CallbackShortcuts`.
class RichTextEditor extends StatefulWidget {
  final quill.QuillController controller;
  final String? hintText;
  final bool expands;
  final bool showToolbar;
  final double minHeight;
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
    final children = <Widget>[];
    if (widget.showToolbar) {
      children.add(_buildToolbar(context));
      children.add(const SizedBox(height: 6));
    }
    children.add(
      widget.expands
          ? Expanded(child: _buildEditor())
          : ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.minHeight,
                maxHeight: widget.maxHeight ?? double.infinity,
              ),
              child: _buildEditor(),
            ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.expands ? MainAxisSize.max : MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildEditor() {
    return quill.QuillEditor.basic(
      controller: widget.controller,
      focusNode: _focusNode,
      scrollController: _scrollController,
      config: quill.QuillEditorConfig(
        placeholder: widget.hintText,
        expands: widget.expands,
        scrollable: true,
        padding: EdgeInsets.zero,
        autoFocus: false,
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Container(
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
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _clearFormatting(widget.controller),
            ),
          ],
        ),
      ),
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