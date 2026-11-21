part of '../space_feed.dart';

extension _FeedNodeExt on _SpaceFeedScreenState {
  Widget _buildNode(
    _PostNode node, {
    required bool searchMode,
    int depth = 0,
  }) {
    final post = node.post;
    final quotes = _quotesByPost[post.id] ?? const <Post>[];
    final quotesExpanded = _expandedQuotes.contains(post.id);
    final totalChildren = node.children.length;
    final hasChildren = totalChildren > 0;
    final isExpanded = searchMode || _expanded.contains(post.id);

    final int previewCount;
    if (isExpanded || depth > 0) {
      previewCount = 0;
    } else if (_collapsedReplies.contains(post.id)) {
      previewCount = 0;
    } else if (!hasChildren) {
      previewCount = 0;
    } else {
      previewCount = totalChildren <= kPreviewReplyCount
          ? totalChildren
          : kPreviewReplyCount;
    }

    final List<_PostNode> visibleChildren;
    if (isExpanded) {
      visibleChildren = node.children;
    } else if (previewCount > 0) {
      visibleChildren = node.children.take(previewCount).toList();
    } else {
      visibleChildren = const [];
    }

    final card = PostCard(
      key: ValueKey(post.id),
      store: widget.store,
      space: widget.space,
      post: post,
      childCount: totalChildren,
      previewCount: previewCount,
      expanded: isExpanded,
      hideReplyToggle: searchMode || _selectionMode,
      onToggleReplies: () => _setStateSafe(() {
        final exp = _expanded.contains(post.id);
        if (exp) {
          _expanded.remove(post.id);
          _collapsedReplies.remove(post.id);
          return;
        }
        if (depth > 0) {
          _expanded.add(post.id);
          _collapsedReplies.remove(post.id);
          return;
        }
        if (_collapsedReplies.contains(post.id)) {
          _collapsedReplies.remove(post.id);
          return;
        }
        if (totalChildren <= kPreviewReplyCount) {
          _collapsedReplies.add(post.id);
        } else {
          _expanded.add(post.id);
        }
      }),
      quoteCount: quotes.length,
      quotesExpanded: quotesExpanded,
      onToggleQuotes: () => _setStateSafe(() {
        if (_expandedQuotes.contains(post.id)) {
          _expandedQuotes.remove(post.id);
        } else {
          _expandedQuotes.add(post.id);
        }
      }),
      onReply: () => _reply(post),
      onQuote: () => _quote(post),
      onEdit: () => _edit(post),
      onDelete: () => widget.store.deletePost(widget.space.id, post.id),
      onQuoteTap: (searchMode || _selectionMode) ? null : _scrollToPost,
      isHighlighted: _highlightedPostId == post.id,
      selectionMode: _selectionMode,
      isSelected: _selectedPostIds.contains(post.id),
      onCardTap: _selectionMode ? () => _toggleSelection(post.id) : null,
      onCardLongPress: (_selectionMode || searchMode)
          ? null
          : () => _enterSelectionMode(post.id),
    );

    final parts = <Widget>[card];
    if (quotesExpanded && quotes.isNotEmpty) {
      parts.add(_buildQuotesSection(quotes));
    }
    if (visibleChildren.isNotEmpty) {
      parts.add(
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 8, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: visibleChildren
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildNode(
                          c,
                          searchMode: searchMode,
                          depth: depth + 1,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      );
    }

    final Widget result = parts.length == 1
        ? parts.first
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: parts,
          );
    return KeyedSubtree(key: _keyFor(post.id), child: result);
  }

  Widget _buildQuotesSection(List<Post> quotes) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final interactive = !_selectionMode && !_searchActive;
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 8, top: 6, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.postQuotedByHeader,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            ...quotes.map((q) => _QuoteBackPreview(
                  store: widget.store,
                  space: widget.space,
                  quotingPost: q,
                  onTap: interactive ? () => _scrollToPost(q.id) : null,
                )),
          ],
        ),
      ),
    );
  }
}