import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/bookmarks.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../util/html_utils.dart';
import '../bookmark_import_helpers.dart';
import '../space_actions.dart';
import '../space_dialogs.dart';
import '../widgets/space_stats_dialog.dart';
import 'drive.dart';
import 'space_feed/attachment_picker.dart';
import 'space_feed/composer.dart';
import 'space_feed/post_card.dart';

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
  void dispose() {
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
    final picked = await pickImportFile(context);
    if (picked == null) return;
    final lower = picked.name.toLowerCase();
    if (lower.endsWith('.zip')) {
      await _importZipIntoCurrent(picked.bytes);
    } else if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      await _importBookmarksIntoCurrent(picked.bytes);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported file type')),
      );
    }
  }

  Future<void> _importZipIntoCurrent(Uint8List bytes) async {
    try {
      final r = await widget.store.importSpaceZipIntoExistingSpace(
        targetSpaceId: widget.space.id,
        zipBytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(spaceImportSummary(r))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importBookmarksIntoCurrent(Uint8List bytes) async {
    BookmarkFile file;
    try {
      file = BookmarkFileParser.parse(
        utf8.decode(bytes, allowMalformed: true),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not parse file: $e')),
        );
      }
      return;
    }
    if (file.bookmarks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No bookmarks found in file')),
        );
      }
      return;
    }
    try {
      final r = await widget.store.importBookmarksIntoSpace(
        spaceId: widget.space.id,
        file: file,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookmarkImportSummary(r))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
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
      );
      if (!mounted) return;
      _bodyCtrl.clear();
      _urlCtrl.clear();
      setState(() {
        _pendingFileIds.clear();
        _postDateTime = null;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final ids = await pickOrRecallFiles(context, widget.store, widget.space);
    if (!mounted || ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        if (!_pendingFileIds.contains(id)) _pendingFileIds.add(id);
      }
    });
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
    );
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
    );
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
    );
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
                  if (v == 'export') {
                    exportSpaceZip(context, widget.store, _space);
                  }
                  if (v == 'delete') _deleteSpace();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'stats', child: Text('Statistics')),
                  PopupMenuItem(value: 'edit', child: Text('Edit space…')),
                  PopupMenuItem(value: 'import', child: Text('Import…')),
                  PopupMenuItem(value: 'export', child: Text('Export space…')),
                  PopupMenuItem(value: 'delete', child: Text('Delete space…')),
                ],
              ),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
              if (!_searchActive)
                _ComposerFooter(
                  child: InlineComposer(
                    kind: _kind,
                    onKindChanged: (k) => setState(() => _kind = k),
                    bodyCtrl: _bodyCtrl,
                    urlCtrl: _urlCtrl,
                    pendingFileIds: _pendingFileIds,
                    store: widget.store,
                    space: widget.space,
                    onAttach: _attach,
                    onSend: _sending ? null : _send,
                    onRemoveFile: (id) =>
                        setState(() => _pendingFileIds.remove(id)),
                    postDateTime: _postDateTime, // ← new
                    onPostDateTimeChanged: (v) =>
                        setState(() => _postDateTime = v), // ← new
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
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
