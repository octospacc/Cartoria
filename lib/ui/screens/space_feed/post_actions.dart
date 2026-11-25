part of 'post_card.dart';

class _PostActions extends StatelessWidget {
  final int childCount;
  final int previewCount;
  final bool expanded;
  final bool hideReplyToggle;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;
  final VoidCallback onQuote;
  final int quoteCount;
  final bool quotesExpanded;
  final VoidCallback? onToggleQuotes;
  final bool selectionMode;
  final bool hasNestedReplies;
  final bool allThreadExpanded;
  final VoidCallback? onToggleThread;

  const _PostActions({
    required this.childCount,
    required this.previewCount,
    required this.expanded,
    required this.hideReplyToggle,
    required this.onToggleReplies,
    required this.onReply,
    required this.onQuote,
    required this.quoteCount,
    required this.quotesExpanded,
    required this.onToggleQuotes,
    this.selectionMode = false,
    this.hasNestedReplies = false,
    this.allThreadExpanded = false,
    this.onToggleThread,
});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    final actionStyle = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );

    final leftActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          ignoring: selectionMode,
          child: TextButton.icon(
            onPressed: onReply,
            icon: const Icon(Icons.reply, size: 15),
            label: Text(l.postReply),
            style: actionStyle,
          ),
        ),
        const SizedBox(width: 2),
        IgnorePointer(
          ignoring: selectionMode,
          child: TextButton.icon(
            onPressed: onQuote,
            icon: const Icon(Icons.format_quote, size: 15),
            label: Text(l.postQuote),
            style: actionStyle,
          ),
        ),
      ],
    );

    final replyToggle = _replyToggle(theme, l);
    final quotesToggle = _quotesToggle(theme, l);

    final threadToggle = (hasNestedReplies && onToggleThread != null)
        ? TextButton.icon(
            onPressed: onToggleThread,
            icon: Icon(
              allThreadExpanded ? Icons.unfold_less : Icons.unfold_more,
              size: 15,
            ),
            label: Text(
              allThreadExpanded
                  ? l.feedCollapseThread
                  : l.feedExpandThread,
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          )
        : null;

    final rightToggles = Wrap(
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (replyToggle != null) replyToggle,
        if (quotesToggle != null) quotesToggle,
        if (threadToggle != null) threadToggle,
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              leftActions,
              if (rightToggles.children.isNotEmpty) ...[
                const SizedBox(height: 4),
                rightToggles,
              ],
            ],
          );
        }
        return Row(
          children: [
            leftActions,
            if (rightToggles.children.isNotEmpty) ...[
              const Spacer(),
              rightToggles,
            ],
          ],
        );
      },
    );
  }

  Widget? _replyToggle(ThemeData theme, AppLocalizations l) {
    if (hideReplyToggle) return null;
    if (childCount == 0) return null;

    final style = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );

    if (expanded) {
      return TextButton.icon(
        onPressed: onToggleReplies,
        icon: const Icon(Icons.expand_less, size: 15),
        label: Text(l.postHideReplies(childCount)),
        style: style,
      );
    }

    if (previewCount > 0) {
      if (previewCount < childCount) {
        final hidden = childCount - previewCount;
        return TextButton.icon(
          onPressed: onToggleReplies,
          icon: const Icon(Icons.expand_more, size: 15),
          label: Text(l.postShowMoreReplies(hidden)),
          style: style,
        );
      }
      return TextButton.icon(
        onPressed: onToggleReplies,
        icon: const Icon(Icons.expand_less, size: 15),
        label: Text(l.postHideReplies(childCount)),
        style: style,
      );
    }

    return TextButton.icon(
      onPressed: onToggleReplies,
      icon: const Icon(Icons.expand_more, size: 15),
      label: Text(l.postRepliesCount(childCount)),
      style: style,
    );
  }

  Widget? _quotesToggle(ThemeData theme, AppLocalizations l) {
    if (hideReplyToggle) return null;
    if (quoteCount == 0) return null;
    if (onToggleQuotes == null) return null;

    final style = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );

    if (quotesExpanded) {
      return TextButton.icon(
        onPressed: onToggleQuotes,
        icon: const Icon(Icons.expand_less, size: 15),
        label: Text(l.postHideQuotes(quoteCount)),
        style: style,
      );
    }
    return TextButton.icon(
      onPressed: onToggleQuotes,
      icon: const Icon(Icons.expand_more, size: 15),
      label: Text(l.postShowQuotes(quoteCount)),
      style: style,
    );
  }
}