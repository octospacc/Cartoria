part of 'composer.dart';

class ComposerSheet extends StatefulWidget {
  final VaultStore store;
  final Space space;
  final Post? editing;
  final Post? replyTo;

  /// The post being quoted, if any. Mutually exclusive with [editing]
  /// in practice — editing preserves the post's existing quote (if any)
  /// and cannot add or remove one via this sheet.
  final Post? quoting;

  const ComposerSheet({
    super.key,
    required this.store,
    required this.space,
    this.editing,
    this.replyTo,
    this.quoting,
  });

  @override
  State<ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<ComposerSheet> {
  late PostKind _kind;
  late TextEditingController _body;
  late TextEditingController _url;
  late TextEditingController _title;
  late TextEditingController _description;
  late List<String> _fileIds;
  String? _thumbnail;
  bool _fetching = false;
  DateTime? _postDateTime;
  bool _skipHooks = false;

  late final ComposerDraftController _draftCtrl;
  bool _loadingDraft = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.editing;
    _kind = existing?.kind ?? PostKind.note;
    _body = TextEditingController(
      text: existing != null ? bodyFromHtml(existing.body) : '',
    );
    _url = TextEditingController(text: existing?.url ?? '');
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _fileIds = existing != null ? List.of(existing.fileIds) : [];
    _thumbnail = existing?.thumbnail;
    // No datetime for edits: creation time is preserved by updatePost,
    // and there's no way to change it without stranding the UUIDv7 order.
    _postDateTime = null;

    _draftCtrl = ComposerDraftController(
      store: widget.store,
      fieldKey: _draftFieldKey,
    );

    _body.addListener(_onAnyFieldChanged);
    _url.addListener(_onAnyFieldChanged);
    _title.addListener(_onAnyFieldChanged);
    _description.addListener(_onAnyFieldChanged);

    _loadDraft();
  }

  @override
  void dispose() {
    // Capture the current state before teardown, unless we're mid-submit
    // (in which case the parent's `deleteComposerDraft` is authoritative
    // and a save here would race it).
    if (!_submitting && !_loadingDraft) {
      final draft = _buildDraft();
      if (_isSameAsBaseline(draft)) {
        _draftCtrl.clear();
      } else {
        _draftCtrl.saveNow(draft);
      }
    }
    _draftCtrl.dispose();
    _body.dispose();
    _url.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _headerTitle {
    final l = context.l10n;
    if (widget.editing != null) return l.composerEditing;
    if (widget.replyTo != null) return l.composerReply;
    if (widget.quoting != null) return l.composerQuote;
    return l.composerNewPost;
  }

  String get _submitLabel {
    final l = context.l10n;
    if (widget.editing != null) return l.commonSave;
    if (widget.replyTo != null) return l.composerReply;
    if (widget.quoting != null) return l.composerQuote;
    return l.composerPost;
  }

  String _previewOf(Post p) {
    if (p.body.isNotEmpty) {
      final t = bodyFromHtml(p.body);
      return t.length > 60 ? '${t.substring(0, 60)}…' : t;
    }
    if (p.title != null && p.title!.isNotEmpty) return p.title!;
    if (p.url != null) return p.url!;
    return '(attachment)';
  }

  Future<void> _addFile() async {
    final ids = await pickOrRecallFiles(context, widget.store, widget.space);
    if (!mounted || ids.isEmpty) return;
    _updateSheetState(() {
      for (final id in ids) {
        if (!_fileIds.contains(id)) _fileIds.add(id);
      }
    });
  }

  Future<void> _refreshMetadata() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.composerUrlRequired)),
      );
      return;
    }
    setState(() => _fetching = true);
    final meta = await widget.store.fetchLinkMetadata(url);
    if (!mounted) return;
    setState(() {
      _fetching = false;
      if (meta != null) {
        _title.text = meta.title ?? '';
        _description.text = meta.description ?? '';
        _thumbnail = meta.image;
      }
    });
    _maybeSaveDraft();
    if (meta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.composerMetadataFetchFailed)),
      );
    }
  }

  void _submit() {
    final url = _kind == PostKind.bookmark ? _url.text.trim() : null;
    if (_kind == PostKind.bookmark && (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.composerBookmarkNeedsUrl)),
      );
      return;
    }
    // Discard any pending debounced save. If we let it fire during the
    // sheet's exit animation, it races the parent's post-submit
    // `deleteComposerDraft` and resurrects the draft for the next open.
    _submitting = true;
    _draftCtrl.discardPending();
    Navigator.pop(
      context,
      ComposerResult(
        kind: _kind,
        body: _body.text.trim(),
        url: url,
        title: _kind == PostKind.bookmark ? _title.text.trim() : null,
        description:
            _kind == PostKind.bookmark ? _description.text.trim() : null,
        thumbnail: _kind == PostKind.bookmark ? _thumbnail : null,
        fileIds: List.of(_fileIds),
        createdAt: widget.editing == null ? _postDateTime : null,
        quotedPostId: widget.editing == null ? widget.quoting?.id : null,
        skipHooks: _skipHooks,
        draftFieldKey: _draftFieldKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _withPasteShortcut(Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(_headerTitle, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(_submitLabel),
                  ),
                ],
              ),
              if (widget.replyTo != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Replying to: ${_previewOf(widget.replyTo!)}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.quoting != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.format_quote,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Quoting: ${_previewOf(widget.quoting!)}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SegmentedButton<PostKind>(
                segments: const [
                  ButtonSegment(
                      value: PostKind.note,
                      icon: Icon(Icons.notes, size: 16),
                      label: Text('Note')),
                  ButtonSegment(
                      value: PostKind.bookmark,
                      icon: Icon(Icons.bookmark_outline, size: 16),
                      label: Text('Link')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) =>
                    _updateSheetState(() => _kind = s.first),
                showSelectedIcon: false,
              ),
              if (_kind == PostKind.bookmark) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _fetching ? null : _refreshMetadata,
                      tooltip: 'Refresh metadata',
                      icon: _fetching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  spellCheckConfiguration: kSpellCheckConfig,
                  contextMenuBuilder: spellCheckContextMenuBuilder,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  spellCheckConfiguration: kSpellCheckConfig,
                  contextMenuBuilder: spellCheckContextMenuBuilder,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_thumbnail != null && _thumbnail!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _thumbnail!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _draftCtrl,
                builder: (context, _) {
                  if (!_draftCtrl.hasRestoredDraft) {
                    return const SizedBox.shrink();
                  }
                  final savedAt = _draftCtrl.restoredDraftSavedAt;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.restore,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unsaved draft'
                            '${savedAt != null ? " from ${_formatRelative(savedAt)}" : ""}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: _discardDraft,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: theme.colorScheme.error,
                          ),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text('Body', style: theme.textTheme.labelLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
                      tooltip: 'Emoji',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => showEmojiPickerSheet(context, _body),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_full, size: 18),
                      tooltip: 'Expand to full screen',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _openFullScreenEditor(context),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 12,
                spellCheckConfiguration: kSpellCheckConfig,
                contextMenuBuilder: spellCheckContextMenuBuilder,
                decoration: const InputDecoration(
                  hintText: 'Write the body…',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.editing == null) ...[
                const SizedBox(height: 12),
                _DateTimeRow(
                  value: _postDateTime,
                  onChanged: (v) => _updateSheetState(() => _postDateTime = v),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('Run hooks on save'),
                  subtitle: Text(
                    _skipHooks
                        ? 'Hooks will be skipped. You can trigger them later from the '
                            'post menu.'
                        : 'Matching hooks will fire when you tap ${_submitLabel.toLowerCase()}.',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: !_skipHooks,
                  onChanged: (v) => _updateSheetState(() => _skipHooks = !v),
                ),
              ),
              const SizedBox(height: 12),
              if (_fileIds.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _fileIds.map((id) {
                    final f = widget.store.fileById(widget.space.id, id);
                    return InputChip(
                      label:
                          Text(f?.name ?? id, overflow: TextOverflow.ellipsis),
                      onDeleted: () =>
                          _updateSheetState(() => _fileIds.remove(id)),
                      onPressed:
                          f == null ? null : () => _openFileViewer(context, f),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addFile,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Add file'),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _openFullScreenEditor(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    final title = widget.editing != null
        ? l.composerFullScreenEditTitle
        : widget.replyTo != null
            ? l.composerFullScreenReplyTitle
            : widget.quoting != null
                ? l.composerFullScreenQuoteTitle
                : l.composerFullScreenNewTitle;
    await FullScreenTextEditor.show(
      context,
      controller: _body,
      title: title,
      hintText: l.composerBodyHint,
    );
  }

  String get _draftFieldKey {
    if (widget.editing != null) return 'post:${widget.editing!.id}:edit';
    if (widget.replyTo != null) return 'post:${widget.replyTo!.id}:reply';
    if (widget.quoting != null) return 'post:${widget.quoting!.id}:quote';
    return 'post:new:${DateTime.now().millisecondsSinceEpoch}';
  }

  void _onAnyFieldChanged() {
    _maybeSaveDraft();
  }

  void _updateSheetState(VoidCallback fn) {
    setState(fn);
    _maybeSaveDraft();
  }

  ComposerDraft _buildDraft() {
    return ComposerDraft(
      fieldKey: _draftFieldKey,
      kind: _kind,
      body: _body.text,
      url: _url.text.isEmpty ? null : _url.text,
      title: _title.text.isEmpty ? null : _title.text,
      description: _description.text.isEmpty ? null : _description.text,
      thumbnail: _thumbnail,
      fileIds: List.of(_fileIds),
      postDateTime: _postDateTime,
      skipHooks: _skipHooks,
      savedAt: DateTime.now().toUtc(),
    );
  }

  /// True when [draft] matches the baseline state — the post's original
  /// content for edits, or the empty state for new / reply / quote.
  ///
  /// A draft matching the baseline is not "unsaved changes"; it's the
  /// starting point. Persisting it would make the "Unsaved draft" banner
  /// appear on every reopen, with nothing actually modified.
  bool _isSameAsBaseline(ComposerDraft draft) {
    final existing = widget.editing;
    if (existing != null) {
      return draft.kind == existing.kind &&
          draft.body == bodyFromHtml(existing.body) &&
          (draft.url ?? '') == (existing.url ?? '') &&
          (draft.title ?? '') == (existing.title ?? '') &&
          (draft.description ?? '') == (existing.description ?? '') &&
          draft.thumbnail == existing.thumbnail &&
          listEquals(draft.fileIds, existing.fileIds) &&
          draft.postDateTime == null &&
          !draft.skipHooks;
    }
    return draft.isEmpty;
  }

  /// Persists the current composer state as a draft, or clears any
  /// existing draft when the state matches the baseline. Also cancels
  /// the previous `scheduleSave` when at baseline, so a pending flush
  /// from a since-reverted change can't resurrect the draft.
  void _maybeSaveDraft() {
    if (_loadingDraft) return;
    final draft = _buildDraft();
    if (_isSameAsBaseline(draft)) {
      _draftCtrl.clear();
    } else {
      _draftCtrl.scheduleSave(draft);
    }
  }

  Future<void> _loadDraft() async {
    final draft = await _draftCtrl.loadRestored();
    if (draft == null || !mounted) return;
    // A draft equal to the post's original content is not "unsaved
    // changes" — it was persisted by a pre-fix build. Drop it silently
    // so the banner never appears when nothing was actually modified.
    if (_isSameAsBaseline(draft)) {
      await _draftCtrl.clear();
      return;
    }
    _loadingDraft = true;
    try {
      setState(() {
        _kind = draft.kind;
        _body.text = draft.body;
        _url.text = draft.url ?? '';
        _title.text = draft.title ?? '';
        _description.text = draft.description ?? '';
        _thumbnail = draft.thumbnail;
        _fileIds
          ..clear()
          ..addAll(draft.fileIds);
        _postDateTime = draft.postDateTime;
        _skipHooks = draft.skipHooks;
      });
    } finally {
      _loadingDraft = false;
    }
  }

  Future<void> _discardDraft() async {
    await _draftCtrl.clear();
    if (!mounted) return;
    _loadingDraft = true;
    try {
      setState(() {
        if (widget.editing != null) {
          final post = widget.editing!;
          _kind = post.kind;
          _body.text = bodyFromHtml(post.body);
          _url.text = post.url ?? '';
          _title.text = post.title ?? '';
          _description.text = post.description ?? '';
          _thumbnail = post.thumbnail;
          _fileIds
            ..clear()
            ..addAll(post.fileIds);
          _postDateTime = null;
          _skipHooks = false;
        } else {
          _kind = PostKind.note;
          _body.clear();
          _url.clear();
          _title.clear();
          _description.clear();
          _thumbnail = null;
          _fileIds.clear();
          _postDateTime = null;
          _skipHooks = false;
        }
      });
    } finally {
      _loadingDraft = false;
    }
  }

  String _formatRelative(DateTime t) {
    final l = context.l10n;
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return l.composerRelativeJustNow;
    if (diff.inMinutes < 60) return l.composerRelativeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l.composerRelativeHours(diff.inHours);
    if (diff.inDays < 30) return l.composerRelativeDays(diff.inDays);
    final local = t.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Widget _withPasteShortcut(Widget child) {
    if (kIsWeb) return child;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final hk = HardwareKeyboard.instance;
        final isMac = defaultTargetPlatform == TargetPlatform.macOS;
        final mod = isMac ? hk.isMetaPressed : hk.isControlPressed;
        if (!mod || event.logicalKey != LogicalKeyboardKey.keyV) {
          return KeyEventResult.ignored;
        }
        _handlePasteShortcut();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

  Future<void> _handlePasteShortcut() async {
    final files = await readClipboardFiles();
    if (!mounted) return;
    if (files.isNotEmpty) {
      final newIds = <String>[];
      for (final f in files) {
        try {
          final file = await widget.store.addFileFromBytes(
            spaceId: widget.space.id,
            bytes: f.bytes,
            name: f.name,
          );
          newIds.add(file.id);
        } catch (e) {
          debugPrint('Paste failed: $e');
        }
      }
      if (mounted && newIds.isNotEmpty) {
        setState(() {
          for (final id in newIds) {
            if (!_fileIds.contains(id)) _fileIds.add(id);
          }
        });
      }
      return;
    }
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (ctx != null) {
      await Actions.maybeInvoke(
        ctx,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    }
  }

  Future<void> _openFileViewer(BuildContext context, DriveFile f) async {
    final siblings = <DriveFile>[];
    for (final id in _fileIds) {
      final df = widget.store.fileById(widget.space.id, id);
      if (df != null) siblings.add(df);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FileViewerScreen(
          store: widget.store,
          space: widget.space,
          file: f,
          allowDelete: true,
          siblings: siblings,
        ),
      ),
    );
    if (!mounted) return;
    for (final id in List.of(_fileIds)) {
      if (widget.store.fileById(widget.space.id, id) == null) {
        _updateSheetState(() => _fileIds.remove(id));
      }
    }
  }
}