import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../l10n/l10n.dart';

/// Bottom sheet listing the posts that reference a drive file.
///
/// If [onViewPostInFeed] is provided, tapping a post dismisses the sheet
/// and invokes it (the caller is expected to navigate to the feed and
/// scroll to the post). If null, the sheet is read-only.
class FileUsageSheet extends StatelessWidget {
  final DriveFile file;
  final List<Post> posts;
  final void Function(String postId)? onViewPostInFeed;

  const FileUsageSheet({
    super.key,
    required this.file,
    required this.posts,
    this.onViewPostInFeed,
  });

  static Future<void> show(
    BuildContext context, {
    required DriveFile file,
    required List<Post> posts,
    void Function(String postId)? onViewPostInFeed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FileUsageSheet(
        file: file,
        posts: posts,
        onViewPostInFeed: onViewPostInFeed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, controller) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.link, size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        posts.isEmpty
                            ? l.fileUsageEmptyTitle
                            : l.fileUsageCount(posts.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l.commonClose,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Expanded(
            child: posts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.fileUsageNoPosts,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _buildItem(context, posts[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, Post post) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final preview = post.plaintext.isNotEmpty
        ? post.plaintext
        : (post.title ?? post.url ?? l.fileUsageNoText);
    final truncated = preview.length > 120
        ? '${preview.substring(0, 120)}…'
        : preview;
    final isBookmark = post.kind == PostKind.bookmark;

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isBookmark
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer,
        child: Text(
          isBookmark ? '🔖' : '📝',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      title: Text(
        truncated,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        post.formattedCreatedAt,
        style: theme.textTheme.bodySmall,
      ),
      trailing: onViewPostInFeed != null
          ? const Icon(Icons.chevron_right, size: 18)
          : null,
      onTap: onViewPostInFeed == null
          ? null
          : () {
              Navigator.pop(context);
              onViewPostInFeed!(post.id);
            },
    );
  }
}