import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/foundation.dart'; // defaultTargetPlatform
import 'package:flutter/services.dart'; // HardwareKeyboard, KeyDownEvent, etc.

import '../../data/bookmarks.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../util/html_utils.dart';
import '../../platform/clipboard_files.dart';
import '../bookmark_import_helpers.dart';
import '../space_actions.dart';
import '../space_dialogs.dart';
import '../widgets/escape_back.dart';
import '../widgets/space_stats_dialog.dart';
import 'drive.dart';
import 'space_feed/attachment_picker.dart';
import 'space_feed/composer.dart';
import 'space_feed/post_card.dart';
import '../../data/composer_draft.dart';
import 'space_feed/composer_draft_controller.dart';

/// Number of direct replies shown under a top-level post by default.
const int kPreviewReplyCount = 2;

class SpaceFeedScreen extends StatefulWidget {
  final VaultStore store;
  final Space space;
  const SpaceFeedScreen({super.key, required this.store, required this.space});

  @override
  State<SpaceFeedScreen> createState() => _SpaceFeedScreenState();
}

class _SpaceFeedScreenState extends State<SpaceFeedScreen> {
  /// Resolves the current version of this space from the store on every
  /// read. `widget.space` is a snapshot from navigation time and becomes
  /// stale as soon as the space is edited (rename, icon change).
  ///
  /// Falls back to `widget.space` when the space has just been deleted
  /// (delete-space calls this in its dialog after `removeWhere`).
  Space get _space => widget.store.spaceById(widget.space.id) ?? widget.space;

  final _bodyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  PostKind _kind = PostKind.note;
  final List<String> _pendingFileIds = [];
  DateTime? _postDateTime;
  final Set<String> _expanded = {};
  bool _sending = false;
  bool _searchActive = false;
  bool _skipHooks = false;

  late final ComposerDraftController _inlineDraftCtrl;
  bool _loadingInlineDraft = false;

  final ItemScrollController _feedScroll = ItemScrollController();
  final ItemScrollController _searchScroll = ItemScrollController();

  final Map<String, GlobalKey> _postKeys = {};
  int _scrollToken = 0;

  GlobalKey _keyFor(String postId) =>
      _postKeys.putIfAbsent(postId, () => GlobalKey());

  bool _selectionMode = false;
  final Set<String> _selectedPostIds = {};

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _selectionMode = true;
      if (initialId != null) _selectedPostIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPostIds.clear();
    });
  }

  void _toggleSelection(String postId) {
    setState(() {
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete ${selected.length} '
          '${selected.length == 1 ? "post" : "posts"}?',
        ),
        content: Text(
          'This cannot be undone.'
          '${orphaned > 0 ? "\n\n$orphaned ${orphaned == 1 ? "reply" : "replies"} will become top-level." : ""}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    await widget.store.deletePosts(widget.space.id, selected);
    if (mounted) _exitSelectionMode();
  }

  @override
  void initState() {
    super.initState();
    _inlineDraftCtrl = ComposerDraftController(
      store: widget.store,
      fieldKey: 'space:${widget.space.id}:inline',
    );
    _bodyCtrl.addListener(_onInlineFieldChanged);
    _urlCtrl.addListener(_onInlineFieldChanged);
    _loadInlineDraft();
  }

  @override
  void dispose() {
    // Flush the *current* composer state to the draft before the
    // controllers die. `_draftCtrl.dispose()` only fires the debounced
    // pending save — which won't exist if the user attached a file and
    // immediately navigated away (no listener fired for the file
    // change). Re-reading the state here captures that case.
    if (!_loadingInlineDraft) {
      _inlineDraftCtrl.saveNow(_buildInlineDraft());
    }
    _inlineDraftCtrl.dispose();
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    _postKeys.clear();
    super.dispose();
  }

  // ── Scroll to a quoted post ────────────────────────────────────────────

  Future<void> _scrollToPost(String postId) async {
    final token = ++_scrollToken;

    if (_searchActive) {
      setState(() {
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

    var changed = false;
    setState(() {
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

  // ── Space actions ──────────────────────────────────────────────────────

  Future<void> _editSpace() async {
    // was:
    //   initialName: widget.space.name,
    //   initialIcon: widget.space.icon,
    final result = await showSpaceDialog(
      context,
      initialName: _space.name,
      initialIcon: _space.icon,
      title: 'Edit space',
      confirmLabel: 'Save',
    );
    if (result == null) return;
    await widget.store.updateSpace(
      widget.space.id,
      name: result.name,
      icon: result.icon,
    );
  }

  Future<void> _importFile() async {
    final picked = await pickImportFiles(context);
    if (picked.isEmpty) return;

    final summaries = <String>[];
    final errorMessages = <String>[];
    var ok = 0;
    var failed = 0;

    for (final p in picked) {
      final result = await _importOneFile(p);
      if (result.error != null) {
        failed++;
        errorMessages.add('${p.name}: ${result.error}');
      } else {
        ok++;
        final s = result.summary;
        if (s != null && s.isNotEmpty) summaries.add(s);
      }
    }

    if (!mounted) return;

    final String message;
    if (picked.length == 1 && ok == 1 && summaries.isNotEmpty) {
      // Single file: preserve the detailed per-format summary.
      message = summaries.first;
    } else {
      final parts = <String>[];
      if (ok > 0) parts.add('$ok file${ok == 1 ? "" : "s"} imported');
      if (failed > 0) parts.add('$failed failed');
      message = parts.isEmpty ? 'Nothing imported' : parts.join(' · ');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: failed > 0
            ? SnackBarAction(
                label: 'Details',
                onPressed: () => _showImportErrors(errorMessages),
              )
            : null,
      ),
    );
  }

  Future<({String? summary, String? error})> _importOneFile(
    ({Uint8List bytes, String name}) p,
  ) async {
    final lower = p.name.toLowerCase();
    try {
      if (lower.endsWith('.zip')) {
        final r = await widget.store.importSpaceZipIntoExistingSpace(
          targetSpaceId: widget.space.id,
          zipBytes: p.bytes,
        );
        return (summary: spaceImportSummary(r), error: null);
      }
      if (lower.endsWith('.html') || lower.endsWith('.htm')) {
        final text = utf8.decode(p.bytes, allowMalformed: true);
        if (text.trimLeft().startsWith('<!---')) {
          await widget.store.importPostFromSource(
            spaceId: widget.space.id,
            source: text,
          );
          return (summary: 'Post imported', error: null);
        }
        final file = BookmarkFileParser.parse(text);
        if (file.bookmarks.isEmpty) {
          return (
            summary: null,
            error: 'No bookmarks found in file',
          );
        }
        final r = await widget.store.importBookmarksIntoSpace(
          spaceId: widget.space.id,
          file: file,
        );
        return (summary: bookmarkImportSummary(r), error: null);
      }
      return (summary: null, error: 'Unsupported file type');
    } catch (e) {
      return (summary: null, error: _friendlyError(e));
    }
  }

  Future<void> _pastePostSource() async {
    final post = await showDialog<Post>(
      context: context,
      builder: (_) => _PastePostSourceDialog(
        store: widget.store,
        spaceId: widget.space.id,
      ),
    );
    if (post == null || !mounted) return;
    // VaultStore.importPostFromSource already called notifyListeners,
    // so the feed updates on the next frame. Confirmation is just UX.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post imported')),
    );
  }

  void _showImportErrors(List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${errors.length} error${errors.length == 1 ? "" : "s"}',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: errors
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SelectableText('· $e'),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSpace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // was: Text('Delete "${widget.space.name}"?')
        title: Text('Delete "${_space.name}"?'),
        content: const Text(
            'This removes every post and file in this space. Cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteSpace(widget.space.id);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Compose / edit / delete posts ──────────────────────────────────────

  List<String> _extractTags(String body) {
    final re = RegExp(r'(?:^|\s)#([A-Za-z0-9_]+)');
    return re.allMatches(body).map((m) => m.group(1)!).toSet().toList();
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    final url = _kind == PostKind.bookmark ? _urlCtrl.text.trim() : null;
    if (_kind == PostKind.bookmark && (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A bookmark needs a URL')),
      );
      return;
    }
    if (body.isEmpty && url == null && _pendingFileIds.isEmpty) return;

    setState(() => _sending = true);
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

      // Suppress draft listeners during the reset. `_bodyCtrl.clear()` and
      // `_urlCtrl.clear()` fire `_onInlineFieldChanged`, which would
      // schedule a save with the *partially* cleared state (body empty,
      // files still present, kind still bookmark). That stale draft would
      // then be persisted 500ms later and reappear on reopen.
      _loadingInlineDraft = true;
      try {
        setState(() {
          _kind = PostKind.note;
          _pendingFileIds.clear();
          _postDateTime = null;
          _skipHooks = false;
        });
        _bodyCtrl.clear();
        _urlCtrl.clear();
      } finally {
        _loadingInlineDraft = false;
      }

      await _inlineDraftCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
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
      setState(() {
        _kind = draft.kind;
        _pendingFileIds
          ..clear()
          ..addAll(draft.fileIds);
        _postDateTime = draft.postDateTime;
        _skipHooks = draft.skipHooks;
      });
      _bodyCtrl.text = draft.body;
      _urlCtrl.text = draft.url ?? '';
    } finally {
      _loadingInlineDraft = false;
    }
  }

  void _onInlineFieldChanged() {
    if (_loadingInlineDraft) return;
    _inlineDraftCtrl.scheduleSave(_buildInlineDraft());
  }

  /// Runs [fn] in setState, then schedules a debounced draft save. Every
  /// state change that affects the persisted draft must go through this —
  /// attaching/removing files, toggling kind, setting datetime, toggling
  /// skipHooks. Without it, those changes sit only in memory until the
  /// next keystroke in the body or URL field triggers the listener.
  void _updateInlineState(VoidCallback fn) {
    setState(fn);
    if (!_loadingInlineDraft) {
      _inlineDraftCtrl.scheduleSave(_buildInlineDraft());
    }
  }

  ComposerDraft _buildInlineDraft() {
    return ComposerDraft(
      fieldKey: _inlineDraftCtrl.fieldKey,
      kind: _kind,
      body: _bodyCtrl.text,
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
      setState(() {
        _kind = PostKind.note;
        _pendingFileIds.clear();
        _postDateTime = null;
        _skipHooks = false;
      });
      _bodyCtrl.clear();
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
    if (mounted) setState(() => _expanded.add(parent.id));
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

  // ── Search / tree ──────────────────────────────────────────────────────

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

  Widget _buildNode(
    _PostNode node, {
    required bool searchMode,
    int depth = 0,
  }) {
    final post = node.post;
    final totalChildren = node.children.length;
    final hasChildren = totalChildren > 0;
    final isExpanded = searchMode || _expanded.contains(post.id);

    final previewCount = (!isExpanded && depth == 0 && hasChildren)
        ? (totalChildren < kPreviewReplyCount
            ? totalChildren
            : kPreviewReplyCount)
        : 0;

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
      onToggleReplies: () => setState(() {
        if (_expanded.contains(post.id)) {
          _expanded.remove(post.id);
        } else {
          _expanded.add(post.id);
        }
      }),
      onReply: () => _reply(post),
      onQuote: () => _quote(post),
      onEdit: () => _edit(post),
      onDelete: () => widget.store.deletePost(widget.space.id, post.id),
      onQuoteTap: (searchMode || _selectionMode) ? null : _scrollToPost,
      // New:
      selectionMode: _selectionMode,
      isSelected: _selectedPostIds.contains(post.id),
      onCardTap: _selectionMode ? () => _toggleSelection(post.id) : null,
      onCardLongPress: (_selectionMode || searchMode)
          ? null
          : () => _enterSelectionMode(post.id),
    );

    Widget result;
    if (visibleChildren.isEmpty) {
      result = card;
    } else {
      result = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card,
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
        ],
      );
    }

    return KeyedSubtree(key: _keyFor(post.id), child: result);
  }

  Widget _buildFeed(List<_PostNode> roots, {required bool searchMode}) {
    if (roots.isEmpty) {
      return _emptyState(searchMode
          ? 'No results for "${_searchCtrl.text.trim()}"'
          : 'Nothing here yet. Write a note or save a link.');
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
    // Text selection and post selection are mutually exclusive: when the
    // user is selecting posts, drag-to-select-text must not compete with
    // tap-to-toggle.
    return _selectionMode ? list : SelectionArea(child: list);
  }

  Widget _buildContent() {
    final query = _searchActive ? _searchCtrl.text.trim() : '';
    if (query.isEmpty) {
      return _buildFeed(_buildTree(), searchMode: false);
    }
    final matches = _computeMatches(query);
    if (matches.isEmpty) {
      return _emptyState('No results for "$query"');
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

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Exit selection',
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          _selectedPostIds.isEmpty
              ? 'Select posts'
              : '${_selectedPostIds.length} selected',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete selected',
            onPressed: _selectedPostIds.isEmpty ? null : _deleteSelectedPosts,
          ),
        ],
      );
    }

    return AppBar(
      leading: _searchActive
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Close search',
              onPressed: () => setState(() {
                _searchCtrl.clear();
                _searchActive = false;
              }),
            )
          : null,
      title: _searchActive
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search this space…',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            )
          : Text('${_space.icon} ${_space.name}'),
      actions: _searchActive
          ? [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: () => setState(_searchCtrl.clear),
                ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: 'Select',
                onPressed: () => _enterSelectionMode(),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: () => setState(() => _searchActive = true),
              ),
              IconButton(
                icon: const Icon(Icons.folder),
                tooltip: 'Drive',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriveScreen(
                      store: widget.store,
                      space: _space,
                      onViewPostInFeed: (postId) {
                        // Pop the drive, then scroll to the post after the pop
                        // animation settles. The drive is always pushed from the
                        // feed, so `Navigator.pop` here unambiguously pops the
                        // drive route.
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (mounted) _scrollToPost(postId);
                        });
                      },
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'stats') {
                    SpaceStatsDialog.show(context, widget.store, _space);
                  }
                  if (v == 'edit') _editSpace();
                  if (v == 'import') _importFile();
                  if (v == 'import-source') _pastePostSource();
                  if (v == 'export') {
                    exportSpaceZip(context, widget.store, _space);
                  }
                  if (v == 'delete') _deleteSpace();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'stats', child: Text('Statistics')),
                  PopupMenuItem(value: 'edit', child: Text('Edit space…')),
                  PopupMenuItem(value: 'import', child: Text('Import…')),
                  PopupMenuItem(
                    value: 'import-source',
                    child: Text('Paste post source…'),
                  ),
                  PopupMenuItem(value: 'export', child: Text('Export space…')),
                  PopupMenuItem(value: 'delete', child: Text('Delete space…')),
                ],
              ),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return EscapeBack(
        onEscape: _selectionMode || _searchActive
            ? () {
                if (_selectionMode) {
                  _exitSelectionMode();
                } else {
                  setState(() {
                    _searchCtrl.clear();
                    _searchActive = false;
                  });
                }
              }
            : null,
        child: withClipboardPasteListener(
            onFiles: _onPastedFiles,
            child: AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) {
                return Scaffold(
                  appBar: _buildAppBar(),
                  body: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: _buildContent(),
                          ),
                        ),
                      ),
                      if (!_searchActive && !_selectionMode)
                        _withPasteShortcut(
                          _ComposerFooter(
                            child: InlineComposer(
                              kind: _kind,
                              onKindChanged: (k) =>
                                  _updateInlineState(() => _kind = k),
                              bodyCtrl: _bodyCtrl,
                              urlCtrl: _urlCtrl,
                              pendingFileIds: _pendingFileIds,
                              store: widget.store,
                              space: widget.space,
                              onAttach: _attach,
                              onSend: _sending ? null : _send,
                              onRemoveFile: (id) => _updateInlineState(
                                  () => _pendingFileIds.remove(id)),
                              postDateTime: _postDateTime,
                              onPostDateTimeChanged: (v) =>
                                  _updateInlineState(() => _postDateTime = v),
                              skipHooks: _skipHooks,
                              onSkipHooksChanged: (v) =>
                                  _updateInlineState(() => _skipHooks = v),
                              onReset: _resetInlineComposer,
                            ),
                          ),
                        )
                    ],
                  ),
                );
              },
            )));
  }

  Future<void> _onPastedFiles(List<ClipboardFile> files) async {
    if (files.isEmpty || !mounted) return;
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Paste failed: $e')),
          );
        }
      }
    }
    if (mounted && newIds.isNotEmpty) {
      setState(() {
        for (final id in newIds) {
          if (!_pendingFileIds.contains(id)) _pendingFileIds.add(id);
        }
      });
    }
  }

  Widget _withPasteShortcut(Widget child) {
    // Web already handles Ctrl+V through the DOM `paste` event listener
    // installed by `withClipboardPasteListener` on the scaffold. Returning
    // `handled` here would call preventDefault() on the underlying
    // keydown, suppress the browser's synthesized paste event, and break
    // both text paste and file paste. The wrapper is native-only.
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
      await _onPastedFiles(files);
      return;
    }
    // No files: fall back to text paste by invoking the standard intent
    // on the currently focused node (the text field the user is typing
    // into). `Actions.maybeInvoke` walks up from that node and finds the
    // EditableText's paste action, so the paste is recorded in the undo
    // history normally.
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (ctx != null) {
      await Actions.maybeInvoke(
        ctx,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    }
  }
}

String _friendlyError(Object e) {
  final s = e.toString();
  const prefixes = [
    'FormatException: ',
    'Exception: ',
    'StateError: ',
    'ArgumentError: ',
  ];
  for (final p in prefixes) {
    if (s.startsWith(p)) return s.substring(p.length);
  }
  return s;
}

class _PostNode {
  final Post post;
  final List<_PostNode> children;
  _PostNode(this.post, this.children);
}

class _ComposerFooter extends StatelessWidget {
  final Widget child;
  const _ComposerFooter({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBanner extends StatelessWidget {
  final int count;
  const _SearchBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.search,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$count ${count == 1 ? "match" : "matches"}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PastePostSourceDialog extends StatefulWidget {
  final VaultStore store;
  final String spaceId;

  const _PastePostSourceDialog({
    required this.store,
    required this.spaceId,
  });

  @override
  State<_PastePostSourceDialog> createState() =>
      _PastePostSourceDialogState();
}

class _PastePostSourceDialogState extends State<_PastePostSourceDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final post = await widget.store.importPostFromSource(
        spaceId: widget.spaceId,
        source: _ctrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
    );

    return EscapeBack(
      child: AlertDialog(
        title: const Text('Paste post source'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Paste a Cartoria post file — the same format as '
                  'entries/<id>.html: a <!--- … ---> JSON frontmatter '
                  'block followed by the HTML body. A fresh ID is '
                  'generated if none is present.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    _error!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              SizedBox(
                height: 300,
                child: TextField(
                  controller: _ctrl,
                  enabled: !_busy,
                  maxLines: null,
                  expands: true,
                  style: mono,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '<!---\n{\n  "kind": "note",\n'
                        '  "created": "2026-01-15T12:00:00.000Z"\n'
                        '}\n--->\n\n<p>Hello</p>',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _import,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Import'),
          ),
        ],
      ),
    );
  }
}