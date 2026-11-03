import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../platform/file_save.dart';
import '../../util/html_utils.dart';
import '../widgets/space_stats_dialog.dart';
import 'drive.dart';
import 'space_feed/attachment_picker.dart';
import 'space_feed/composer.dart';
import 'space_feed/post_card.dart';

class SpaceFeedScreen extends StatefulWidget {
  final VaultStore store;
  final Space space;
  const SpaceFeedScreen({super.key, required this.store, required this.space});

  @override
  State<SpaceFeedScreen> createState() => _SpaceFeedScreenState();
}

class _SpaceFeedScreenState extends State<SpaceFeedScreen> {
  final _bodyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  PostKind _kind = PostKind.note;
  final List<String> _pendingFileIds = [];
  final Set<String> _expanded = {};
  bool _sending = false;
  bool _searchActive = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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
      );
      if (!mounted) return;
      _bodyCtrl.clear();
      _urlCtrl.clear();
      setState(() => _pendingFileIds.clear());
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
    );
    if (mounted) setState(() => _expanded.add(parent.id));
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

  Future<void> _exportSpace() async {
    try {
      final bytes = await widget.store.exportSpaceZip(widget.space.id);
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9T]'), '')
          .substring(0, 15);
      await saveOrShareFile(bytes, 'space-${widget.space.name}-$stamp.zip');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _deleteSpace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${widget.space.name}"?'),
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
      buf.write(bodyFromHtml(p.body));
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

  Widget _buildNode(_PostNode node, {required bool searchMode}) {
    final post = node.post;
    final hasChildren = node.children.isNotEmpty;
    final expanded = searchMode || _expanded.contains(post.id);

    final card = PostCard(
      key: ValueKey(post.id),
      store: widget.store,
      space: widget.space,
      post: post,
      childCount: node.children.length,
      expanded: expanded,
      hideReplyToggle: searchMode,
      onToggleReplies: () => setState(() {
        if (_expanded.contains(post.id)) {
          _expanded.remove(post.id);
        } else {
          _expanded.add(post.id);
        }
      }),
      onReply: () => _reply(post),
      onEdit: () => _edit(post),
      onDelete: () => widget.store.deletePost(widget.space.id, post.id),
    );

    if (!hasChildren || !expanded) return card;

    return Column(
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
              children: node.children
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildNode(c, searchMode: searchMode),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeed(List<_PostNode> roots, {required bool searchMode}) {
    if (roots.isEmpty) {
      return _emptyState(searchMode
          ? 'No results for "${_searchCtrl.text.trim()}"'
          : 'No posts yet. Write something.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: roots.length,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildNode(roots[i], searchMode: searchMode),
        );
      },
    );
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
          : Text('${widget.space.icon} ${widget.space.name}'),
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
                      space: widget.space,
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'stats') {
                    SpaceStatsDialog.show(
                        context, widget.store, widget.space);
                  }
                  if (v == 'export') _exportSpace();
                  if (v == 'delete') _deleteSpace();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'stats', child: Text('Statistics')),
                  PopupMenuItem(
                      value: 'export', child: Text('Export this space…')),
                  PopupMenuItem(
                      value: 'delete', child: Text('Delete this space…')),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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