part of '../space_feed.dart';

extension _FeedSelectionExt on _SpaceFeedScreenState {
  void _enterSelectionMode([String? initialId]) {
    _setStateSafe(() {
      _selectionMode = true;
      if (initialId != null) _selectedPostIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    _setStateSafe(() {
      _selectionMode = false;
      _selectedPostIds.clear();
    });
  }

  void _toggleSelection(String postId) {
    _setStateSafe(() {
      if (_selectedPostIds.contains(postId)) {
        _selectedPostIds.remove(postId);
      } else {
        _selectedPostIds.add(postId);
      }
    });
  }

  Future<void> _deleteSelectedPosts() async {
    final selected = Set<String>.from(_selectedPostIds);
    if (selected.isEmpty) return;

    final posts = widget.store.postsForSpace(widget.space.id);
    final orphaned = posts
        .where((p) =>
            p.parentId != null &&
            selected.contains(p.parentId) &&
            !selected.contains(p.id))
        .length;

    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.feedDeleteSelectedTitle(selected.length)),
        content: Text(
          '${l.feedDeleteSelectedBody}'
          '${orphaned > 0 ? "\n\n${l.feedDeleteSelectedOrphaned(orphaned)}" : ""}',
        ),
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
    if (ok != true) return;

    await widget.store.deletePosts(widget.space.id, selected);
    if (mounted) _exitSelectionMode();
  }
}