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

    // Thread-level expansion: a shorthand for manually expanding every
    // reply under a top-level post that itself has nested replies.
    final descendantIds = <String>{};
    void collectDescendants(_PostNode n) {
      for (final c in n.children) {
        descendantIds.add(c.post.id);
        collectDescendants(c);
      }
    }
    collectDescendants(node);
    final hasNestedReplies =
        depth == 0 && node.children.any((c) => c.children.isNotEmpty);
    final allThreadExpanded = descendantIds.isNotEmpty &&
        _expanded.contains(post.id) &&
        descendantIds.every(_expanded.contains);

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
      hideReplyToggle: searchMode,
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
      onQuoteTap: (searchMode || _selectionMode) ? null : _handleQuoteTap,
      isHighlighted: _highlightedPostId == post.id,
      selectionMode: _selectionMode,
      isSelected: _selectedPostIds.contains(post.id),
      onCardTap: _selectionMode
          ? () => _toggleSelection(post.id)
          : (searchMode ? () => _scrollToPost(post.id) : null),
      onCardLongPress: (_selectionMode || searchMode)
          ? null
          : () => _enterSelectionMode(post.id),
      hasNestedReplies: hasNestedReplies,
      allThreadExpanded: allThreadExpanded,
      onToggleThread: () => _setStateSafe(() {
        if (allThreadExpanded) {
          _expanded.remove(post.id);
          for (final id in descendantIds) {
            _expanded.remove(id);
          }
        } else {
          _expanded.add(post.id);
          _collapsedReplies.remove(post.id);
          for (final id in descendantIds) {
            _expanded.add(id);
          }
        }
      }),
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

  void _handleQuoteTap(String postId, String spaceId) {
    if (spaceId == widget.space.id) {
      _scrollToPost(postId);
    } else {
      _navigateToPostInSpace(spaceId, postId);
    }
  }

  void _navigateToPostInSpace(String spaceId, String postId) {
    final target = widget.store.spaceById(spaceId);
    if (target == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpaceFeedScreen(
          store: widget.store,
          space: target,
          initialPostId: postId,
        ),
      ),
    );
  }
}