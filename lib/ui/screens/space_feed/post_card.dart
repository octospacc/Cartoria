import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../util/file_category.dart';
import '../../../util/hook_outcome.dart';
import '../../widgets/file_thumbnail.dart';
import '../../widgets/hook_status_dialog.dart';
import '../../widgets/post_source_dialog.dart';
import '../../widgets/post_body.dart';
import 'inline_media.dart';
import 'link_preview_card.dart';
import 'media_widgets.dart';

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

  /// Number of posts in the space that quote this one. Zero hides the
  /// quotes toggle.
  final int quoteCount;

  /// Whether the inline quotes list is currently expanded.
  final bool quotesExpanded;

  /// Toggle for the quotes section. Null hides the toggle entirely.
  final VoidCallback? onToggleQuotes;

  /// When true, internal interactive controls are disabled and the whole
  /// card becomes a tap target for toggling selection.
  final bool selectionMode;
  final bool isSelected;

  /// Tap handler for the whole card. In selection mode, the caller
  /// should pass a toggle-selection callback; outside selection mode,
  /// the caller may pass null (taps do nothing) or a handler for a
  /// future single-tap action.
  final VoidCallback? onCardTap;

  /// Long-press handler for the whole card. Outside selection mode, the
  /// caller passes a handler to *enter* selection mode with this post
  /// pre-selected. In selection mode, pass null (already in mode).
  final VoidCallback? onCardLongPress;

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

    // Border + background for the selection state.
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6);
    final backgroundColor = isSelected
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.surfaceContainerLow,
          )
        : theme.colorScheme.surfaceContainerLow;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        onLongPress: onCardLongPress,
        borderRadius: BorderRadius.circular(12),
        child: IgnorePointer(
          // In selection mode, taps on the whole card toggle selection;
          // internal buttons, links, quote cards, media are all disabled
          // so nothing competes with the toggle.
          ignoring: selectionMode,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 2 : 1,
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
                          selectionMode: selectionMode,
                          isSelected: isSelected,
                          hookOutcome: _hookOutcome(store, post),
                          onEdit: onEdit,
                          onDelete: () => _confirmDelete(context),
                          onShowSource: () =>
                              showPostSourceDialog(context, store, space, post),
                          // Always available — the dialog offers manual runs for applicable
                          // hooks even when nothing has fired yet.
                          onHookStatus: () => showHookStatusDialog(
                              context, post, store, space.id),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: visualFiles
                                  .map((f) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: InlineMedia(
                                          key: ValueKey('${post.id}-${f.id}'),
                                          store: store,
                                          spaceId: space.id,
                                          file: f,
                                          siblings: files, // ← new
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
                                      spaceId: space.id, // ← was: space: space
                                      file: f))
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
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _QuotedExternalCard(quote: q),
                                  ))
                              .toList(),
                        ],
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

// ── Quote cards (unchanged) ────────────────────────────────────────────────

class _QuotedOwnCard extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final String quotedPostId;
  final VoidCallback? onTap;

  const _QuotedOwnCard({
    required this.store,
    required this.space,
    required this.quotedPostId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quoted = _find();

    final inner = Padding(
      padding: const EdgeInsets.all(10),
      child: quoted == null
          ? Row(
              children: [
                Icon(Icons.link_off,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Quoted post unavailable',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          : _quotedContent(context, theme, quoted),
    );

    final decorated = Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: decorated,
      ),
    );
  }

  Widget _quotedContent(BuildContext context, ThemeData theme, Post quoted) {
    final icon =
        quoted.kind == PostKind.bookmark ? Icons.bookmark_outline : Icons.notes;
    final preview = _previewOf(quoted);
    final media = _mediaPreview(context, quoted);
    final mediaFiles = _mediaFiles(quoted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Quoted from this space',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_outward,
                  size: 12, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ],
        if (mediaFiles.isNotEmpty) media,
        if (quoted.quotedExternals.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '↪ includes another quote',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  List<DriveFile> _mediaFiles(Post quoted) {
    return quoted.fileIds
        .map((id) => store.fileById(space.id, id))
        .whereType<DriveFile>()
        .where((f) {
          final cat = categoryFor(f.name);
          return cat == FileCategory.image || cat == FileCategory.video;
        })
        .take(4)
        .toList();
  }

  Widget _mediaPreview(BuildContext context, Post quoted) {
    final files = _mediaFiles(quoted);
    if (files.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: files.map((f) {
          final isVideo = categoryFor(f.name) == FileCategory.video;
          return SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideo)
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.videocam,
                        size: 24,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    FileThumbnail(
                      store: store,
                      spaceId: space.id,
                      file: f,
                      iconSize: 24,
                    ),
                  if (isVideo)
                    Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
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

  Post? _find() {
    for (final p in store.postsForSpace(space.id)) {
      if (p.id == quotedPostId) return p;
    }
    return null;
  }
}

class _QuotedExternalCard extends StatelessWidget {
  final QuotedExternal quote;

  const _QuotedExternalCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUri = quote.uri != null && quote.uri!.isNotEmpty;
    final label = (quote.author != null && quote.author!.isNotEmpty)
        ? quote.author!
        : 'External quote';

    final content = quote.text.isNotEmpty
        ? quote.text
        : (hasUri ? 'Tap to view the quoted post' : '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasUri ? () => _open(context, quote.uri!) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.format_quote,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasUri)
                    Icon(Icons.open_in_new,
                        size: 12, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  content,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    fontStyle: quote.text.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String atUri) async {
    final httpUrl = _atUriToHttp(atUri);
    if (httpUrl == null) return;
    final uri = Uri.tryParse(httpUrl);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $httpUrl')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  static String? _atUriToHttp(String atUri) {
    if (!atUri.startsWith('at://')) return null;
    final rest = atUri.substring(5);
    final parts = rest.split('/');
    if (parts.length != 3) return null;
    final did = parts[0];
    final collection = parts[1];
    final rkey = parts[2];
    if (collection != 'app.bsky.feed.post') return null;
    return 'https://bsky.app/profile/$did/post/$rkey';
  }
}

// ── Avatar, header, tags, actions ─────────────────────────────────────────

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
                    context.l10n.postEdited(edited),
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
                PopupMenuItem(
                    value: 'edit', child: Text(context.l10n.postEdit)),
                PopupMenuItem(
                    value: 'source', child: Text(context.l10n.postSource)),
                if (onHookStatus != null)
                  PopupMenuItem(
                      value: 'hook-status',
                      child: Text(context.l10n.postHookStatus)),
                PopupMenuItem(
                    value: 'delete', child: Text(context.l10n.postDelete)),
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
        tooltip = context.l10n.postHookRunning;
        break;
      case HookOutcome.success:
        final successColor = theme.brightness == Brightness.dark
            ? Colors.green.shade400
            : Colors.green.shade700;
        visual = Icon(Icons.check_circle, size: 14, color: successColor);
        tooltip = context.l10n.postHookSuccess;
        break;
      case HookOutcome.failure:
        visual = Icon(
          Icons.error,
          size: 14,
          color: theme.colorScheme.error,
        );
        tooltip = context.l10n.postHookFailed;
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    // Left zone: compose actions. Neutral colour — they're the normal
    // interaction path.
    final actionStyle = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );

    final leftActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onReply,
          icon: const Icon(Icons.reply, size: 15),
          label: Text(l.postReply),
          style: actionStyle,
        ),
        const SizedBox(width: 2),
        TextButton.icon(
          onPressed: onQuote,
          icon: const Icon(Icons.format_quote, size: 15),
          label: Text(l.postQuote),
          style: actionStyle,
        ),
      ],
    );

    // Right zone: expand toggles. Primary colour + chevron — reads as
    // "navigation / reveal", visually distinct from the compose actions.
    final replyToggle = _replyToggle(theme, l);
    final quotesToggle = _quotesToggle(theme, l);

    final rightToggles = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyToggle != null) replyToggle,
        if (replyToggle != null && quotesToggle != null)
          const SizedBox(width: 2),
        if (quotesToggle != null) quotesToggle,
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

    final hidden = childCount - previewCount;
    if (hidden <= 0) return null;

    if (previewCount > 0) {
      return TextButton.icon(
        onPressed: onToggleReplies,
        icon: const Icon(Icons.expand_more, size: 15),
        label: Text(l.postShowMoreReplies(hidden)),
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
    if (hideReplyToggle) return null; // same suppression as replies
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