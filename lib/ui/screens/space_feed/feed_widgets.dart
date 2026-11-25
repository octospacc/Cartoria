part of '../space_feed.dart';

class _PostNode {
  final Post post;
  final List<_PostNode> children;
  _PostNode(this.post, this.children);
}

class _ComposerFooter extends StatelessWidget {
  final Widget child;
  const _ComposerFooter({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBanner extends StatelessWidget {
  final int count;
  final DateTimeRange? dateRange;
  final VoidCallback? onClearDateRange;

  const _SearchBanner({
    required this.count,
    this.dateRange,
    this.onClearDateRange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.search,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(l.feedSearchMatches(count), style: theme.textTheme.bodySmall),
          if (dateRange != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.searchDateRangeLabel(
                      _fmt(dateRange!.start),
                      _fmt(dateRange!.end),
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onClearDateRange,
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _QuoteBackPreview extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final Post quotingPost;
  final VoidCallback? onTap;

  const _QuoteBackPreview({
    required this.store,
    required this.space,
    required this.quotingPost,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBookmark = quotingPost.kind == PostKind.bookmark;
    final preview = _previewOf(quotingPost);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isBookmark
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.secondaryContainer,
                child: Text(
                  isBookmark ? '🔖' : '📝',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quotingPost.formattedCreatedAt,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_outward,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _previewOf(Post p) {
    if (p.plaintext.isNotEmpty) return p.plaintext;
    if (p.title != null && p.title!.isNotEmpty) return p.title!;
    if (p.description != null && p.description!.isNotEmpty) {
      return p.description!;
    }
    if (p.url != null) return p.url!;
    return '';
  }
}