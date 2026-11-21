part of 'post_card.dart';

class _PostAvatar extends StatelessWidget {
  final bool isBookmark;
  final ThemeData theme;
  const _PostAvatar({required this.isBookmark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isBookmark
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          isBookmark ? '🔖' : '📝',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final Post post;
  final HookOutcome hookOutcome;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShowSource;
  final VoidCallback? onHookStatus;

  const _PostHeader({
    required this.post,
    required this.hookOutcome,
    required this.selectionMode,
    required this.isSelected,
    required this.onEdit,
    required this.onDelete,
    required this.onShowSource,
    this.onHookStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final subtle = theme.colorScheme.onSurfaceVariant;
    final edited = post.formattedEditedAt;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                post.formattedCreatedAt,
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.bodySmall?.copyWith(color: subtle),
              ),
              if (edited != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l.postEdited(edited),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: subtle),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hookOutcome != HookOutcome.none && !selectionMode) ...[
          const SizedBox(width: 4),
          _HookIndicator(outcome: hookOutcome, onTap: onHookStatus),
        ],
        if (selectionMode)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          SizedBox(
            height: 24,
            width: 28,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'source') onShowSource();
                if (v == 'delete') onDelete();
                if (v == 'hook-status') onHookStatus?.call();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.postEdit)),
                PopupMenuItem(value: 'source', child: Text(l.postSource)),
                if (onHookStatus != null)
                  PopupMenuItem(
                      value: 'hook-status',
                      child: Text(l.postHookStatus)),
                PopupMenuItem(value: 'delete', child: Text(l.postDelete)),
              ],
            ),
          ),
      ],
    );
  }
}

class _HookIndicator extends StatelessWidget {
  final HookOutcome outcome;
  final VoidCallback? onTap;

  const _HookIndicator({required this.outcome, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    final Widget visual;
    final String tooltip;
    switch (outcome) {
      case HookOutcome.running:
        visual = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
        tooltip = l.postHookRunning;
        break;
      case HookOutcome.success:
        final successColor = theme.brightness == Brightness.dark
            ? Colors.green.shade400
            : Colors.green.shade700;
        visual = Icon(Icons.check_circle, size: 14, color: successColor);
        tooltip = l.postHookSuccess;
        break;
      case HookOutcome.failure:
        visual = Icon(
          Icons.error,
          size: 14,
          color: theme.colorScheme.error,
        );
        tooltip = l.postHookFailed;
        break;
      case HookOutcome.none:
        return const SizedBox.shrink();
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: visual,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '#$tag',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}