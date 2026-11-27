part of '../space_feed.dart';

extension _FeedScrollExt on _SpaceFeedScreenState {
  Future<void> _scrollToPost(String postId) async {
    if (!mounted) return;
    final token = ++_scrollToken;

    if (_searchActive) {
      _setStateSafe(() {
        _searchCtrl.clear();
        _searchActive = false;
        _searchDateRange = null;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
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
      if (!mounted) return;
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
    // No ensureVisible afterwards — GlobalKeys are gone, and the flash
    // highlight already makes the target visible for the ~1.4s it stays
    // on. scrollTo lands within one card-height of the target which is
    // close enough for the user to spot the highlight.
  }

  void _flashHighlight(String postId) {
    if (!mounted) return;
    _highlightTimer?.cancel();
    _setStateSafe(() => _highlightedPostId = postId);
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _highlightedPostId == postId) {
        _setStateSafe(() => _highlightedPostId = null);
      }
    });
  }
}