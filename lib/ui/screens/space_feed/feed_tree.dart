part of '../space_feed.dart';

extension _FeedTreeExt on _SpaceFeedScreenState {
  Set<String> _computeMatches(String query) {
    final terms = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return {};
    final spaceId = widget.space.id;
    final posts = widget.store.postsForSpace(spaceId);
    final matches = <String>{};
    for (final p in posts) {
      final buf = StringBuffer();
      buf.write(p.plaintext);
      buf.write(' ');
      if (p.title != null) {
        buf.write(p.title);
        buf.write(' ');
      }
      if (p.description != null) {
        buf.write(p.description);
        buf.write(' ');
      }
      if (p.url != null) {
        buf.write(p.url);
        buf.write(' ');
      }
      for (final t in p.tags) {
        buf.write(t);
        buf.write(' ');
      }
      for (final fid in p.fileIds) {
        final f = widget.store.fileById(spaceId, fid);
        if (f != null) {
          buf.write(f.name);
          buf.write(' ');
        }
      }
      for (final q in p.quotedExternals) {
        buf.write(q.text);
        buf.write(' ');
        if (q.author != null) {
          buf.write(q.author);
          buf.write(' ');
        }
      }
      final hay = buf.toString().toLowerCase();
      if (terms.every(hay.contains)) {
        matches.add(p.id);
      }
    }
    return matches;
  }

  Set<String> _withAncestors(Set<String> matches) {
    final posts = widget.store.postsForSpace(widget.space.id);
    final byId = {for (final p in posts) p.id: p};
    final result = {...matches};
    for (final id in matches) {
      var cur = byId[id];
      while (cur?.parentId != null) {
        final pid = cur!.parentId!;
        if (result.contains(pid)) break;
        result.add(pid);
        cur = byId[pid];
      }
    }
    return result;
  }

  Widget _emptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  List<_PostNode> _buildTree({Set<String>? visible}) {
    final allPosts = widget.store.postsForSpace(widget.space.id);
    final posts = visible == null
        ? allPosts
        : allPosts.where((p) => visible.contains(p.id)).toList();
    final ids = {for (final p in posts) p.id};
    final childrenByParent = <String?, List<Post>>{};
    for (final p in posts) {
      final parentKey =
          (p.parentId != null && ids.contains(p.parentId)) ? p.parentId : null;
      childrenByParent.putIfAbsent(parentKey, () => []).add(p);
    }
    for (final list in childrenByParent.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    _PostNode buildNode(Post post) {
      final children =
          (childrenByParent[post.id] ?? const []).map(buildNode).toList();
      return _PostNode(post, children);
    }

    return (childrenByParent[null] ?? const [])
        .reversed
        .map(buildNode)
        .toList();
  }

  void _refreshQuotesMap() {
    final all = widget.store.postsForSpace(widget.space.id);
    final map = <String, List<Post>>{};
    for (final p in all) {
      final qid = p.quotedPostId;
      if (qid == null || qid == p.id) continue;
      map.putIfAbsent(qid, () => <Post>[]).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    _quotesByPost = map;
  }

  Widget _buildContent() {
    _refreshQuotesMap();
    final query = _searchActive ? _searchCtrl.text.trim() : '';
    if (query.isEmpty) {
      return _buildFeed(_buildTree(), searchMode: false);
    }
    final matches = _computeMatches(query);
    if (matches.isEmpty) {
      return _emptyState(context.l10n.feedSearchNoResults(query));
    }
    final visible = _withAncestors(matches);
    final roots = _buildTree(visible: visible);
    return Column(
      children: [
        _SearchBanner(count: matches.length),
        Expanded(child: _buildFeed(roots, searchMode: true)),
      ],
    );
  }

  Widget _buildFeed(List<_PostNode> roots, {required bool searchMode}) {
    if (roots.isEmpty) {
      return _emptyState(searchMode
          ? context.l10n.feedSearchNoResults(_searchCtrl.text.trim())
          : context.l10n.feedEmpty);
    }
    final list = ScrollablePositionedList.builder(
      itemScrollController: searchMode ? _searchScroll : _feedScroll,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: roots.length,
      itemBuilder: (context, i) {
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildNode(roots[i], searchMode: searchMode),
          ),
        );
      },
    );
    return _selectionMode ? list : SelectionArea(child: list);
  }
}