import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../util/file_category.dart';
import '../../widgets/hook_status_dialog.dart';
import 'inline_media.dart';
import 'link_preview_card.dart';
import 'media_widgets.dart';

class PostCard extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final Post post;
  final int childCount;

  /// How many direct children are currently visible due to preview (before
  /// the user expands). 0 for nested posts and for roots that are already
  /// expanded. Passed by `SpaceFeedScreen`; the card only uses it to pick
  /// the right button text.
  final int previewCount;
  final bool expanded;
  final bool hideReplyToggle;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PostCard({
    super.key,
    required this.store,
    required this.space,
    required this.post,
    required this.childCount,
    this.previewCount = 0,
    required this.expanded,
    this.hideReplyToggle = false,
    required this.onToggleReplies,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = post.fileIds
        .map((id) => store.fileById(space.id, id))
        .whereType<DriveFile>()
        .toList();
    final plaintext = post.plaintext;
    final isBookmark = post.kind == PostKind.bookmark;

    final visualFiles = <DriveFile>[];
    final attachmentFiles = <DriveFile>[];
    for (final f in files) {
      final cat = categoryFor(f.name);
      if (cat == FileCategory.image ||
          cat == FileCategory.video ||
          cat == FileCategory.audio ||
          cat == FileCategory.text) {
        visualFiles.add(f);
      } else {
        attachmentFiles.add(f);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostAvatar(isBookmark: isBookmark, theme: theme),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostHeader(
                    post: post,
                    onEdit: onEdit,
                    onDelete: () => _confirmDelete(context),
                    onHookStatus: post.hookState.isEmpty
                        ? null
                        : () => showHookStatusDialog(context, post, store),
                  ),
                  if (plaintext.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      plaintext,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (isBookmark && post.url != null) ...[
                    const SizedBox(height: 8),
                    LinkPreviewCard(post: post),
                  ],
                  if (visualFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: visualFiles
                            .map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InlineMedia(
                                    key: ValueKey('${post.id}-${f.id}'),
                                    store: store,
                                    spaceId: space.id,
                                    file: f,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  if (attachmentFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: attachmentFiles
                            .map((f) => FileRow(
                                store: store, space: space, file: f))
                            .toList(),
                      ),
                    ),
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          post.tags.map((t) => _TagChip(tag: t)).toList(),
                    ),
                  ],
                  const SizedBox(height: 2),
                  _PostActions(
                    childCount: childCount,
                    previewCount: previewCount,
                    expanded: expanded,
                    hideReplyToggle: hideReplyToggle,
                    onToggleReplies: onToggleReplies,
                    onReply: onReply,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
            'Attached files stay in the drive. Replies will become top-level. Cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) onDelete();
  }
}

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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Null when the post has no hook state yet — the menu item is hidden
  /// rather than shown disabled, so a fresh post stays uncluttered.
  final VoidCallback? onHookStatus;

  const _PostHeader({
    required this.post,
    required this.onEdit,
    required this.onDelete,
    this.onHookStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurfaceVariant;
    final edited = post.formattedEditedAt;

    return Row(
      children: [
        // Outer Expanded takes `available - 28` so the fixed-width menu
        // button is always flush with the card's right edge, whether or
        // not the edited segment is present.
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
                    '· edited $edited',
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
        SizedBox(
          height: 24,
          width: 28,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 18,
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
              if (v == 'hook-status') onHookStatus?.call();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
              if (onHookStatus != null)
                const PopupMenuItem(
                  value: 'hook-status',
                  child: Text('Hook status…'),
                ),
            ],
          ),
        ),
      ],
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

class _PostActions extends StatelessWidget {
  final int childCount;
  final int previewCount;
  final bool expanded;
  final bool hideReplyToggle;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;

  const _PostActions({
    required this.childCount,
    required this.previewCount,
    required this.expanded,
    required this.hideReplyToggle,
    required this.onToggleReplies,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggle = _replyToggle(theme);
    return Row(
      children: [
        TextButton.icon(
          onPressed: onReply,
          icon: const Icon(Icons.reply, size: 15),
          label: const Text('Reply'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ),
        if (toggle != null) ...[
          const SizedBox(width: 2),
          toggle,
        ],
      ],
    );
  }

  Widget? _replyToggle(ThemeData theme) {
    if (hideReplyToggle) return null;
    if (childCount == 0) return null;

    final style = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );

    if (expanded) {
      if (previewCount > 0) {
        // Root expanded: clicking reduces to preview, not to zero.
        return TextButton(
          onPressed: onToggleReplies,
          style: style,
          child: const Text('Show fewer'),
        );
      }
      // Nested expanded: clicking collapses fully (unchanged).
      return TextButton(
        onPressed: onToggleReplies,
        style: style,
        child: Text(
          'Hide $childCount ${childCount == 1 ? "reply" : "replies"}',
        ),
      );
    }

    final hidden = childCount - previewCount;
    if (hidden <= 0) {
      // Root preview where all children fit inside the preview slot.
      return null;
    }

    if (previewCount > 0) {
      // Root preview: some are already visible, so say how many more.
      return TextButton(
        onPressed: onToggleReplies,
        style: style,
        child: Text(
          'Show $hidden more ${hidden == 1 ? "reply" : "replies"}',
        ),
      );
    }

    // Nested collapsed (unchanged).
    return TextButton(
      onPressed: onToggleReplies,
      style: style,
      child: Text(
        '$childCount ${childCount == 1 ? "reply" : "replies"}',
      ),
    );
  }
}