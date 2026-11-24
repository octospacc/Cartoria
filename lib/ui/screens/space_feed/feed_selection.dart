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
        if (_selectedPostIds.isEmpty) {
          _selectionMode = false;
        }
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

  Future<void> _copySelectedPosts({bool includeDate = false}) async {
    final selected = Set<String>.from(_selectedPostIds);
    if (selected.isEmpty) return;

    final all = widget.store.postsForSpace(widget.space.id);
    final selectedPosts =
        all.where((p) => selected.contains(p.id)).toList();
    if (selectedPosts.isEmpty) return;

    final plaintext = includeDate
        ? postsToPlaintextDated(selectedPosts)
        : postsToPlaintext(selectedPosts);
    final html = await _buildCopyHtml(selectedPosts, includeDate);

    await copyToClipboard(plaintext: plaintext, html: html);

    if (!mounted) return;
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.feedCopiedToClipboard(selectedPosts.length))),
    );
    _exitSelectionMode();
  }

  /// Builds the clipboard HTML for [posts], embedding image attachments
  /// as base64 data URIs so they survive paste into rich destinations
  /// (email, notes, docs). A per-post and total size cap prevents one
  /// huge image from blowing past browser clipboard limits or making
  /// the copy take minutes on slow disks.
  ///
  /// Returns null when no post has any text, formatting, URL, or image
  /// — nothing worth pasting as rich.
  Future<String?> _buildCopyHtml(
    List<Post> posts,
    bool includeDate,
  ) async {
    const perImageMax = 5 * 1024 * 1024; // 5 MB
    const totalBudget = 20 * 1024 * 1024; // 20 MB
    var totalBytes = 0;

    final buf = StringBuffer();
    var hasContent = false;

    for (var i = 0; i < posts.length; i++) {
      final post = posts[i];
      final postBuf = StringBuffer();

      if (includeDate) {
        postBuf.write(
          '<p><small>[${formatPostDate(post.createdAt)}]</small></p>\n',
        );
      }
      if (post.title != null && post.title!.isNotEmpty) {
        postBuf.write(
          '<p><strong>${escapeHtml(post.title!)}</strong></p>\n',
        );
      }
      if (post.body.isNotEmpty) {
        postBuf.write(post.body);
        postBuf.write('\n');
      }

      // Embed images.
      for (final fileId in post.fileIds) {
        final file = widget.store.fileById(widget.space.id, fileId);
        if (file == null) continue;
        if (categoryFor(file.name) != FileCategory.image) continue;
        try {
          final bytes = await widget.store.readFileBytes(
            widget.space.id,
            fileId,
          );
          if (bytes.length > perImageMax) continue;
          if (totalBytes + bytes.length > totalBudget) continue;
          totalBytes += bytes.length;
          final mime = mimeTypeForName(file.name);
          final b64 = base64Encode(bytes);
          postBuf.write(
            '<p><img src="data:$mime;base64,$b64" '
            'alt="${escapeHtml(file.name)}" /></p>\n',
          );
        } catch (_) {
          // Skip images we can't load — text still goes through.
        }
      }

      if (post.url != null &&
          post.url!.isNotEmpty &&
          !post.body.contains(post.url!)) {
        final escUrl = escapeHtml(post.url!);
        postBuf.write('<p><a href="$escUrl">$escUrl</a></p>\n');
      }

      final postHtml = postBuf.toString().trim();
      if (postHtml.isEmpty) continue;
      if (hasContent) buf.write('<hr>\n');
      buf.write(postHtml);
      hasContent = true;
    }

    if (!hasContent) return null;
    return buf.toString();
  }
}