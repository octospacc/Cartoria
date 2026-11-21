part of '../space_feed.dart';

extension _FeedScrollExt on _SpaceFeedScreenState {
  Future<void> _scrollToPost(String postId) async {
    final token = ++_scrollToken;

    if (_searchActive) {
      _setStateSafe(() {
        _searchCtrl.clear();
        _searchActive = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (token != _scrollToken) return;
    }

    final roots = _buildTree();
    final chain = <String>[];
    int? rootIndex;
    bool find(_PostNode node, List<String> path) {
      path.add(node.post.id);
      if (node.post.id == postId) return true;
      for (final c in node.children) {
        if (find(c, path)) return true;
      }
      path.removeLast();
      return false;
    }

    for (var i = 0; i < roots.length; i++) {
      if (find(roots[i], chain)) {
        rootIndex = i;
        break;
      }
    }
    if (rootIndex == null) return;
    if (token != _scrollToken) return;

    _flashHighlight(postId);

    var changed = false;
    _setStateSafe(() {
      for (var i = 0; i < chain.length - 1; i++) {
        if (!_expanded.contains(chain[i])) {
          _expanded.add(chain[i]);
          changed = true;
        }
      }
    });
    if (changed) {
      await WidgetsBinding.instance.endOfFrame;
      if (token != _scrollToken) return;
    }

    if (!_feedScroll.isAttached) return;
    try {
      await _feedScroll.scrollTo(
        index: rootIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    } catch (_) {
      return;
    }
    if (token != _scrollToken) return;

    if (postId != chain.first) {
      await WidgetsBinding.instance.endOfFrame;
      if (token != _scrollToken) return;
      final ctx = _postKeys[postId]?.currentContext;
      if (ctx != null) {
        try {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            alignment: 0.05,
          );
        } catch (_) {}
      }
    }
  }

  void _flashHighlight(String postId) {
    _highlightTimer?.cancel();
    _setStateSafe(() => _highlightedPostId = postId);
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _highlightedPostId == postId) {
        _setStateSafe(() => _highlightedPostId = null);
      }
    });
  }
}