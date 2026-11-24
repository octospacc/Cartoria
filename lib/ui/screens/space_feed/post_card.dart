library post_card;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../l10n/l10n.dart';
import '../../../util/file_category.dart';
import '../../../util/hook_outcome.dart';
import '../../widgets/file_thumbnail.dart';
import '../../widgets/hook_status_dialog.dart';
import '../../widgets/post_body.dart';
import '../../widgets/post_source_dialog.dart';
import 'inline_media.dart';
import 'link_preview_card.dart';
import 'media_widgets.dart';

part 'post_header.dart';
part 'post_actions.dart';
part 'post_quote_cards.dart';

class PostCard extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final Post post;
  final int childCount;
  final int previewCount;
  final bool expanded;
  final bool hideReplyToggle;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;
  final VoidCallback onQuote;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String quotedPostId)? onQuoteTap;

  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onCardTap;
  final VoidCallback? onCardLongPress;

  final int quoteCount;
  final bool quotesExpanded;
  final VoidCallback? onToggleQuotes;

  /// Whether the overflow menu offers an "Open in feed" entry. Only
  /// true in search mode, where tapping the card body also navigates.
  final bool showGoToPost;

  /// Called when the user picks "Open in feed" from the overflow menu.
  /// Null hides the entry even when `showGoToPost` is true.
  final VoidCallback? onGoToPost;

  /// True while the post is the target of a just-completed scroll-to.
  /// Renders a brief accent that fades in/out via an animated container.
  /// Independent of [isSelected], which is the multi-select state.
  final bool isHighlighted;

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
    required this.onQuote,
    required this.onEdit,
    required this.onDelete,
    this.onQuoteTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onCardTap,
    this.onCardLongPress,
    this.quoteCount = 0,
    this.quotesExpanded = false,
    this.onToggleQuotes,
    this.showGoToPost = false,
    this.onGoToPost,
    this.isHighlighted = false,
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

    final Color borderColor;
    final Color backgroundColor;
    final double borderWidth;
    if (isSelected) {
      borderColor = theme.colorScheme.primary;
      backgroundColor = Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.08),
        theme.colorScheme.surfaceContainerLow,
      );
      borderWidth = 2;
    } else if (isHighlighted) {
      borderColor = theme.colorScheme.primary;
      backgroundColor = Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.14),
        theme.colorScheme.surfaceContainerLow,
      );
      borderWidth = 2;
    } else {
      borderColor =
          theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
      backgroundColor = theme.colorScheme.surfaceContainerLow;
      borderWidth = 1;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        onLongPress: onCardLongPress,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
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
                      IgnorePointer(
                        ignoring: selectionMode,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PostHeader(
                              post: post,
                              selectionMode: selectionMode,
                              isSelected: isSelected,
                              hookOutcome: _hookOutcome(store, post),
                              onEdit: onEdit,
                              onDelete: () => _confirmDelete(context),
                              onShowSource: () => showPostSourceDialog(
                                  context, store, space, post),
                              onHookStatus: () => showHookStatusDialog(
                                  context, post, store, space.id),
                              showGoToPost: showGoToPost,
                              onGoToPost: onGoToPost,
                            ),
                            if (plaintext.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              PostBodyText(
                                html: post.body,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(height: 1.4),
                                imageCache: store.htmlImageCache,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: visualFiles
                                      .map((f) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6),
                                            child: InlineMedia(
                                              key: ValueKey(
                                                  '${post.id}-${f.id}'),
                                              store: store,
                                              spaceId: space.id,
                                              file: f,
                                              siblings: files,
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
                                          store: store,
                                          spaceId: space.id,
                                          file: f))
                                      .toList(),
                                ),
                              ),
                            if (post.tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: post.tags
                                    .map((t) => _TagChip(tag: t))
                                    .toList(),
                              ),
                            ],
                            if (post.quotedPostId != null) ...[
                              const SizedBox(height: 8),
                              _QuotedOwnCard(
                                store: store,
                                space: space,
                                quotedPostId: post.quotedPostId!,
                                onTap: onQuoteTap == null
                                    ? null
                                    : () => onQuoteTap!(post.quotedPostId!),
                              ),
                            ],
                            if (post.quotedExternals.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...post.quotedExternals
                                  .map((q) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 6),
                                        child: _QuotedExternalCard(quote: q),
                                      ))
                                  .toList(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      _PostActions(
                        childCount: childCount,
                        previewCount: previewCount,
                        expanded: expanded,
                        hideReplyToggle: hideReplyToggle,
                        onToggleReplies: onToggleReplies,
                        onReply: onReply,
                        onQuote: onQuote,
                        quoteCount: quoteCount,
                        quotesExpanded: quotesExpanded,
                        onToggleQuotes: onToggleQuotes,
                        selectionMode: selectionMode,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  HookOutcome _hookOutcome(VaultStore store, Post post) {
    return hookOutcomeFor(
      hasActive: store.hasActiveHooks(post.id),
      states: post.hookState,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          post.kind == PostKind.bookmark
              ? l.postDeleteBookmark
              : l.postDeleteNote,
        ),
        content: Text(l.postDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (ok == true) onDelete();
  }
}