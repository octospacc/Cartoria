part of '../space_feed.dart';

extension _FeedComposeExt on _SpaceFeedScreenState {
  List<String> _extractTags(String body) {
    final re = RegExp(
      r'(?:^|\s)#([\p{L}\p{N}\p{M}_]+)',
      unicode: true,
    );
    return re.allMatches(body).map((m) => m.group(1)!).toSet().toList();
  }

  /// True when the rich editor is active for the inline composer.
  bool get _inlineRich =>
      widget.store.richEditorEnabled && _inlineQuillCtrl != null;

  /// Reads the current inline body text via whichever controller is
  /// active. Always returns plaintext — callers that need HTML use
  /// `_inlineHtml` instead.
  String _inlineText() {
    if (_inlineRich) return quillToPlaintext(_inlineQuillCtrl!);
    return _bodyCtrl.text;
  }

  /// HTML form of the inline body, or null when the rich editor is off.
  String? _inlineHtml() {
    if (!_inlineRich) return null;
    final html = quillToHtml(_inlineQuillCtrl!);
    return html.isEmpty ? null : html;
  }

  Future<void> _send() async {
    final l = context.l10n;
    final body = _inlineText().trim();
    final url = _kind == PostKind.bookmark ? _urlCtrl.text.trim() : null;
    if (_kind == PostKind.bookmark && (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.composerBookmarkNeedsUrl)),
      );
      return;
    }
    if (body.isEmpty && url == null && _pendingFileIds.isEmpty) return;

    _setStateSafe(() => _sending = true);
    String? fetchedTitle;
    String? fetchedDescription;
    String? fetchedThumbnail;
    if (url != null && url.isNotEmpty) {
      final meta = await widget.store.fetchLinkMetadata(url);
      if (meta != null) {
        fetchedTitle = meta.title;
        fetchedDescription = meta.description;
        fetchedThumbnail = meta.image;
      }
    }

    try {
      await widget.store.createPost(
        spaceId: widget.space.id,
        kind: _kind,
        plaintextBody: body,
        bodyHtml: _inlineHtml(),
        url: url,
        title: fetchedTitle,
        description: fetchedDescription,
        thumbnail: fetchedThumbnail,
        tags: _extractTags(body),
        fileIds: List.of(_pendingFileIds),
        createdAt: _postDateTime,
        skipHooks: _skipHooks,
      );
      if (!mounted) return;

      _loadingInlineDraft = true;
      try {
        _setStateSafe(() {
          _kind = PostKind.note;
          _pendingFileIds.clear();
          _postDateTime = null;
          _skipHooks = false;
        });
        _bodyCtrl.clear();
        _resetQuillToEmpty();
        _urlCtrl.clear();
      } finally {
        _loadingInlineDraft = false;
      }

      await _inlineDraftCtrl.clear();
    } finally {
      if (mounted) _setStateSafe(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final ids = await pickOrRecallFiles(context, widget.store, widget.space);
    if (!mounted || ids.isEmpty) return;
    _updateInlineState(() {
      for (final id in ids) {
        if (!_pendingFileIds.contains(id)) _pendingFileIds.add(id);
      }
    });
  }

  Future<void> _loadInlineDraft() async {
    final draft = await _inlineDraftCtrl.loadRestored();
    if (draft == null || !mounted) return;
    _loadingInlineDraft = true;
    try {
      _setStateSafe(() {
        _kind = draft.kind;
        _pendingFileIds
          ..clear()
          ..addAll(draft.fileIds);
        _postDateTime = draft.postDateTime;
        _skipHooks = draft.skipHooks;
        // If rich mode is off but the draft has a delta, preserve it.
        // Switching back to rich without editing restores the
        // formatting; editing in plain mode clears it.
        _preservedBodyDelta =
            (!_inlineRich && draft.bodyDelta != null) ? draft.bodyDelta : null;
      });
      _bodyCtrl.text = draft.body;
      if (_inlineQuillCtrl != null) {
        _replaceInlineQuill(quillFromDraft(
          body: draft.body,
          bodyDelta: draft.bodyDelta,
        ));
      }
      _urlCtrl.text = draft.url ?? '';
    } finally {
      _loadingInlineDraft = false;
    }
  }

  void _onInlineFieldChanged() {
    if (_loadingInlineDraft) return;
    // Any edit in plain mode invalidates the preserved rich delta.
    if (!_inlineRich && _preservedBodyDelta != null) {
      _setStateSafe(() => _preservedBodyDelta = null);
    }
    _inlineDraftCtrl.scheduleSave(_buildInlineDraft());
  }

  void _updateInlineState(VoidCallback fn) {
    _setStateSafe(fn);
    if (!_loadingInlineDraft) {
      _inlineDraftCtrl.scheduleSave(_buildInlineDraft());
    }
  }

  ComposerDraft _buildInlineDraft() {
    return ComposerDraft(
      fieldKey: _inlineDraftCtrl.fieldKey,
      kind: _kind,
      body: _inlineText(),
      bodyDelta: _inlineRich
          ? quillToDeltaJson(_inlineQuillCtrl!)
          : _preservedBodyDelta,
      url: _urlCtrl.text.isEmpty ? null : _urlCtrl.text,
      fileIds: List.of(_pendingFileIds),
      postDateTime: _postDateTime,
      skipHooks: _skipHooks,
      savedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _resetInlineComposer() async {
    await _inlineDraftCtrl.clear();
    if (!mounted) return;
    _loadingInlineDraft = true;
    try {
      _setStateSafe(() {
        _kind = PostKind.note;
        _pendingFileIds.clear();
        _postDateTime = null;
        _skipHooks = false;
        _preservedBodyDelta = null;
      });
      _bodyCtrl.clear();
      _resetQuillToEmpty();
      _urlCtrl.clear();
    } finally {
      _loadingInlineDraft = false;
    }
  }

  Future<void> _reply(Post parent) async {
    final result = await showModalBottomSheet<ComposerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ComposerSheet(
        store: widget.store,
        space: widget.space,
        replyTo: parent,
      ),
    );
    if (result == null) return;

    String? title = result.title;
    String? description = result.description;
    String? thumbnail = result.thumbnail;
    if (result.kind == PostKind.bookmark &&
        result.url != null &&
        result.url!.isNotEmpty &&
        title == null &&
        description == null &&
        thumbnail == null) {
      final meta = await widget.store.fetchLinkMetadata(result.url!);
      if (meta != null) {
        title = meta.title;
        description = meta.description;
        thumbnail = meta.image;
      }
    }

    await widget.store.createPost(
      spaceId: widget.space.id,
      kind: result.kind,
      plaintextBody: result.body,
      bodyHtml: result.bodyHtml,
      url: result.url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      parentId: parent.id,
      tags: _extractTags(result.body),
      fileIds: result.fileIds,
      createdAt: result.createdAt,
      skipHooks: result.skipHooks,
    );
    await widget.store.deleteComposerDraft(result.draftFieldKey);
    if (mounted) {
      _setStateSafe(() {
        _expanded.add(parent.id);
        _collapsedReplies.remove(parent.id);
      });
    }
  }

  Future<void> _quote(Post post) async {
    final result = await showModalBottomSheet<ComposerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ComposerSheet(
        store: widget.store,
        space: widget.space,
        quoting: post,
      ),
    );
    if (result == null) return;

    String? title = result.title;
    String? description = result.description;
    String? thumbnail = result.thumbnail;
    if (result.kind == PostKind.bookmark &&
        result.url != null &&
        result.url!.isNotEmpty &&
        title == null &&
        description == null &&
        thumbnail == null) {
      final meta = await widget.store.fetchLinkMetadata(result.url!);
      if (meta != null) {
        title = meta.title;
        description = meta.description;
        thumbnail = meta.image;
      }
    }

    await widget.store.createPost(
      spaceId: widget.space.id,
      kind: result.kind,
      plaintextBody: result.body,
      bodyHtml: result.bodyHtml,
      url: result.url,
      title: title,
      description: description,
      thumbnail: thumbnail,
      tags: _extractTags(result.body),
      fileIds: result.fileIds,
      createdAt: result.createdAt,
      quotedPostId: result.quotedPostId,
      skipHooks: result.skipHooks,
    );
    await widget.store.deleteComposerDraft(result.draftFieldKey);
  }

  Future<void> _edit(Post post) async {
    final result = await showModalBottomSheet<ComposerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ComposerSheet(
        store: widget.store,
        space: widget.space,
        editing: post,
      ),
    );
    if (result == null) return;
    await widget.store.updatePost(
      spaceId: widget.space.id,
      postId: post.id,
      kind: result.kind,
      plaintextBody: result.body,
      bodyHtml: result.bodyHtml,
      url: result.url,
      title: result.title,
      description: result.description,
      thumbnail: result.thumbnail,
      tags: _extractTags(result.body),
      fileIds: result.fileIds,
      skipHooks: result.skipHooks,
    );
    await widget.store.deleteComposerDraft(result.draftFieldKey);
  }
}