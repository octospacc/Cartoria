part of 'composer.dart';

class ComposerSheet extends StatefulWidget {
  final VaultStore store;
  final Space space;
  final Post? editing;
  final Post? replyTo;
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
  late quill.QuillController? _quillCtrl;
  late TextEditingController _plainBody;
  late TextEditingController _url;
  late TextEditingController _title;
  late TextEditingController _description;
  late List<String> _fileIds;
  String? _thumbnail;
  bool _fetching = false;
  DateTime? _postDateTime;
  bool _skipHooks = false;
  String? _targetSpaceId;

  String? _initialDelta;
  String? _preservedBodyDelta;
  String _lastPlainText = '';

  late final ComposerDraftController _draftCtrl;
  bool _loadingDraft = false;
  bool _submitting = false;

  bool get _rich => widget.store.richEditorEnabled;

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

  String get _draftFieldKey {
    if (widget.editing != null) return 'post:${widget.editing!.id}:edit';
    if (widget.replyTo != null) return 'post:${widget.replyTo!.id}:reply';
    if (widget.quoting != null) return 'post:${widget.quoting!.id}:quote';
    return 'post:new:${DateTime.now().millisecondsSinceEpoch}';
  }

  bool get _hasRichContentToLose {
    if (widget.editing != null &&
        htmlHasFormatting(widget.editing!.body)) {
      return true;
    }
    return _preservedBodyDelta != null;
  }

  String _bodyText() {
    if (_rich && _quillCtrl != null) return quillToPlaintext(_quillCtrl!);
    return _plainBody.text;
  }

  String? _bodyHtml() {
    if (!_rich || _quillCtrl == null) return null;
    final h = quillToHtml(_quillCtrl!);
    return h.isEmpty ? null : h;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.editing;
    _kind = existing?.kind ?? PostKind.note;

    if (widget.store.richEditorEnabled) {
      _quillCtrl = existing != null
          ? quillFromHtml(existing.body)
          : quill.QuillController(
              document: quill.Document(),
              selection: const TextSelection.collapsed(offset: 0),
            );
      _initialDelta = quillToDeltaJson(_quillCtrl!);
      _quillCtrl!.addListener(_onAnyFieldChanged);
      _plainBody = TextEditingController();
    } else {
      _quillCtrl = null;
      _initialDelta = null;
      _plainBody = TextEditingController(
        text: existing != null ? bodyFromHtml(existing.body) : '',
      );
      _lastPlainText = _plainBody.text;
      _plainBody.addListener(_onAnyFieldChanged);
    }

    _url = TextEditingController(text: existing?.url ?? '');
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _fileIds = existing != null ? List.of(existing.fileIds) : [];
    _thumbnail = existing?.thumbnail;
    _postDateTime = null;
    _targetSpaceId = widget.quoting != null ? widget.space.id : null;

    _draftCtrl = ComposerDraftController(
      store: widget.store,
      fieldKey: _draftFieldKey,
    );

    _url.addListener(_onAnyFieldChanged);
    _title.addListener(_onAnyFieldChanged);
    _description.addListener(_onAnyFieldChanged);

    _loadDraft();
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyEsc);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyEsc);
    if (!_submitting && !_loadingDraft) {
      _draftCtrl.saveNow(_buildDraft());
    }
    _draftCtrl.dispose();
    _quillCtrl?.removeListener(_onAnyFieldChanged);
    _quillCtrl?.dispose();
    _plainBody.dispose();
    _url.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
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

  Future<void> _insertEmoji() async {
    if (_rich && _quillCtrl != null) {
      final emoji = await pickEmoji(context);
      if (emoji == null || !mounted) return;
      final sel = _quillCtrl!.selection;
      final index =
          sel.isValid ? sel.start : _quillCtrl!.document.length - 1;
      _quillCtrl!.document.insert(index, emoji);
      _quillCtrl!.updateSelection(
        TextSelection.collapsed(offset: index + emoji.length),
        quill.ChangeSource.local,
      );
    } else {
      await showEmojiPickerSheet(context, _plainBody);
    }
  }

  Future<void> _refreshMetadata() async {
    final l = context.l10n;
    final url = _url.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.composerUrlRequired)),
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
        SnackBar(content: Text(l.composerMetadataFetchFailed)),
      );
    }
  }

  void _submit() {
    final l = context.l10n;
    final url = _kind == PostKind.bookmark ? _url.text.trim() : null;
    if (_kind == PostKind.bookmark && (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.composerBookmarkNeedsUrl)),
      );
      return;
    }
    _submitting = true;
    _draftCtrl.discardPending();
    _preservedBodyDelta = null;
    Navigator.pop(
      context,
      ComposerResult(
        kind: _kind,
        body: _bodyText().trim(),
        bodyHtml: _bodyHtml(),
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
        targetSpaceId: widget.quoting != null
            ? (_targetSpaceId ?? widget.space.id)
            : null,
      ),
    );
  }

  void _onAnyFieldChanged() {
    if (_loadingDraft) return;
    if (!_rich && _plainBody.text != _lastPlainText) {
      _lastPlainText = _plainBody.text;
      if (_preservedBodyDelta != null) {
        setState(() => _preservedBodyDelta = null);
      }
    }
    _draftCtrl.scheduleSave(_buildDraft());
  }

  void _updateSheetState(VoidCallback fn) {
    setState(fn);
    if (!_loadingDraft) {
      _draftCtrl.scheduleSave(_buildDraft());
    }
  }

  ComposerDraft _buildDraft() {
    return ComposerDraft(
      fieldKey: _draftFieldKey,
      kind: _kind,
      body: _bodyText(),
      bodyDelta: _rich && _quillCtrl != null
          ? quillToDeltaJson(_quillCtrl!)
          : _preservedBodyDelta,
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

  bool _isSameAsBaseline(ComposerDraft draft) {
    final existing = widget.editing;
    if (existing == null) return draft.isEmpty;
    if (_rich) {
      if (draft.bodyDelta != _initialDelta) return false;
    } else {
      if (draft.body != bodyFromHtml(existing.body)) return false;
    }
    return draft.kind == existing.kind &&
        (draft.url ?? '') == (existing.url ?? '') &&
        (draft.title ?? '') == (existing.title ?? '') &&
        (draft.description ?? '') == (existing.description ?? '') &&
        draft.thumbnail == existing.thumbnail &&
        _listEquals(draft.fileIds, existing.fileIds) &&
        draft.postDateTime == null &&
        !draft.skipHooks;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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
    if (_isSameAsBaseline(draft)) {
      await _draftCtrl.clear();
      return;
    }
    _loadingDraft = true;
    try {
      if (_rich && _quillCtrl != null) {
        _replaceQuill(quillFromDraft(
          body: draft.body,
          bodyDelta: draft.bodyDelta,
        ));
      } else {
        _plainBody.text = draft.body;
        _lastPlainText = draft.body;
        if (!_rich && draft.bodyDelta != null) {
          _preservedBodyDelta = draft.bodyDelta;
        }
      }
      setState(() {
        _kind = draft.kind;
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
          if (_rich && _quillCtrl != null) {
            _replaceQuill(quillFromHtml(post.body));
          } else {
            _plainBody.text = bodyFromHtml(post.body);
            _lastPlainText = _plainBody.text;
          }
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
          if (_rich && _quillCtrl != null) {
            _replaceQuill(quill.QuillController(
              document: quill.Document(),
              selection: const TextSelection.collapsed(offset: 0),
            ));
          } else {
            _plainBody.clear();
            _lastPlainText = '';
          }
          _url.clear();
          _title.clear();
          _description.clear();
          _thumbnail = null;
          _fileIds.clear();
          _postDateTime = null;
          _skipHooks = false;
        }
        _preservedBodyDelta = null;
      });
    } finally {
      _loadingDraft = false;
    }
  }

  void _replaceQuill(quill.QuillController newCtrl) {
    _quillCtrl?.removeListener(_onAnyFieldChanged);
    _quillCtrl?.dispose();
    _quillCtrl = newCtrl;
    _quillCtrl!.addListener(_onAnyFieldChanged);
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
    if (_rich && _quillCtrl != null) {
      await FullScreenTextEditor.show(
        context,
        controller: _quillCtrl!,
        title: title,
        hintText: l.composerBodyHint,
      );
    } else {
      await FullScreenPlainTextEditor.show(
        context,
        controller: _plainBody,
        title: title,
        hintText: l.composerBodyHint,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    final sheetBody = _withPasteShortcut(Padding(
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
                    child: Text(l.commonCancel),
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
                          l.composerReplyingTo(_previewOf(widget.replyTo!)),
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
                          l.composerQuotingPreview(_previewOf(widget.quoting!)),
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
                segments: [
                  ButtonSegment(
                      value: PostKind.note,
                      icon: const Icon(Icons.notes, size: 16),
                      label: Text(l.composerNote)),
                  ButtonSegment(
                      value: PostKind.bookmark,
                      icon: const Icon(Icons.bookmark_outline, size: 16),
                      label: Text(l.composerLink)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) =>
                    _updateSheetState(() => _kind = s.first),
                showSelectedIcon: false,
              ),
              if (widget.quoting != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l.composerPostIn,
                        style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _targetSpaceId ?? widget.space.id,
                        isDense: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: widget.store.spaces
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text('${s.icon} ${s.name}',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (v) {
                                if (v != null) {
                                  _updateSheetState(
                                      () => _targetSpaceId = v);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
              if (_kind == PostKind.bookmark) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: l.composerUrlLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _fetching ? null : _refreshMetadata,
                      tooltip: l.composerRefreshMetadata,
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
                  decoration: InputDecoration(
                    labelText: l.composerTitleLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  spellCheckConfiguration: kSpellCheckConfig,
                  contextMenuBuilder: spellCheckContextMenuBuilder,
                  decoration: InputDecoration(
                    labelText: l.composerDescriptionLabel,
                    border: const OutlineInputBorder(),
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
                            savedAt != null
                                ? l.composerUnsavedDraftFrom(
                                    _formatRelative(savedAt))
                                : l.composerUnsavedDraft,
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
                          child: Text(l.composerDraftReset),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (!_rich && _hasRichContentToLose) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.composerRichFormattingLossWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(l.composerBodyLabel,
                        style: theme.textTheme.labelLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
                      tooltip: l.composerEmojiTooltip,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _insertEmoji,
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_full, size: 18),
                      tooltip: l.composerExpand,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _openFullScreenEditor(context),
                    ),
                  ],
                ),
              ),
              if (_rich && _quillCtrl != null)
                Container(
                  constraints:
                      const BoxConstraints(minHeight: 140, maxHeight: 260),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: RichTextEditor(
                    controller: _quillCtrl!,
                    hintText: l.composerBodyHint,
                    expands: true,
                  ),
                )
              else
                TextField(
                  controller: _plainBody,
                  minLines: 3,
                  maxLines: 12,
                  spellCheckConfiguration: kSpellCheckConfig,
                  contextMenuBuilder: spellCheckContextMenuBuilder,
                  decoration: InputDecoration(
                    hintText: l.composerBodyHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (widget.editing == null) ...[
                const SizedBox(height: 12),
                _DateTimeRow(
                  value: _postDateTime,
                  onChanged: (v) =>
                      _updateSheetState(() => _postDateTime = v),
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
                  title: Text(l.composerHooksRunOnSave),
                  subtitle: Text(
                    _skipHooks
                        ? l.composerHooksWillSkip
                        : l.composerHooksWillRun(_submitLabel.toLowerCase()),
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
                  label: Text(l.composerAddFile),
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    return sheetBody;
  }

  /// Runs before the focus tree so ESC works even when the URL, title,
  /// description, or the rich body editor is focused.
  KeyEventResult _handleEarlyEsc(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (!mounted) return KeyEventResult.ignored;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return KeyEventResult.ignored;
    Navigator.of(context).pop();
    return KeyEventResult.handled;
  }
}