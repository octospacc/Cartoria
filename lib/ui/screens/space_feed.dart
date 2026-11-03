import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../platform/file_save.dart';
import '../../platform/media.dart';
import '../../util/file_category.dart';
import '../../util/html_utils.dart';
import '../widgets/recall_files_sheet.dart';
import '../widgets/space_stats_dialog.dart';
import 'drive.dart';

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
    final ids = await _pickOrRecallFiles(context, widget.store, widget.space);
    if (!mounted || ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        if (!_pendingFileIds.contains(id)) _pendingFileIds.add(id);
      }
    });
  }

  Future<void> _reply(Post parent) async {
    final result = await showModalBottomSheet<_ComposerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposerSheet(
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
    final result = await showModalBottomSheet<_ComposerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposerSheet(
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

    final card = _PostCard(
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
                  child: _Composer(
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

// ── Post card ──────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final Post post;
  final int childCount;
  final bool expanded;
  final bool hideReplyToggle;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostCard({
    super.key,
    required this.store,
    required this.space,
    required this.post,
    required this.childCount,
    required this.expanded,
    this.hideReplyToggle = false,
    required this.onToggleReplies,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = post.fileIds
        .map((id) => store.fileById(space.id, id))
        .whereType<DriveFile>()
        .toList();
    final plaintext = bodyFromHtml(post.body);
    final isBookmark = post.kind == PostKind.bookmark;

    final visualFiles = <DriveFile>[];
    final attachmentFiles = <DriveFile>[];
    for (final f in files) {
      final cat = categoryFor(f.name);
      if (cat == FileCategory.image ||
          cat == FileCategory.video ||
          cat == FileCategory.audio ||
          cat == FileCategory.text) {
        visualFiles.add(f);
      } else {
        attachmentFiles.add(f);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostAvatar(isBookmark: isBookmark, theme: theme),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostHeader(
                    post: post,
                    onEdit: onEdit,
                    onDelete: () => _confirmDelete(context),
                  ),
                  if (plaintext.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      plaintext,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (isBookmark && post.url != null) ...[
                    const SizedBox(height: 8),
                    _LinkPreviewCard(post: post),
                  ],
                  if (visualFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: visualFiles
                            .map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _InlineMedia(
                                    key: ValueKey('${post.id}-${f.id}'),
                                    store: store,
                                    spaceId: space.id,
                                    file: f,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  if (attachmentFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: attachmentFiles
                            .map((f) =>
                                _FileRow(store: store, space: space, file: f))
                            .toList(),
                      ),
                    ),
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          post.tags.map((t) => _TagChip(tag: t)).toList(),
                    ),
                  ],
                  const SizedBox(height: 2),
                  _PostActions(
                    childCount: childCount,
                    expanded: expanded,
                    hideReplyToggle: hideReplyToggle,
                    onToggleReplies: onToggleReplies,
                    onReply: onReply,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
            'Attached files stay in the drive. Replies will become top-level. Cannot be undone.'),
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
    if (ok == true) onDelete();
  }
}

class _PostAvatar extends StatelessWidget {
  final bool isBookmark;
  final ThemeData theme;
  const _PostAvatar({required this.isBookmark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isBookmark
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          isBookmark ? '🔖' : '📝',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final Post post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PostHeader({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Text(
          _fmt(post.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(color: subtle),
        ),
        if (post.editedAt != null) ...[
          const SizedBox(width: 4),
          Text(
            '· edited',
            style: theme.textTheme.bodySmall?.copyWith(color: subtle),
          ),
        ],
        const Spacer(),
        SizedBox(
          height: 24,
          width: 28,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 18,
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime t) {
    final now = DateTime.now();
    final local = t.toLocal();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hh:$mm';
    final ymd = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    return '$ymd $hh:$mm';
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '#$tag',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _PostActions extends StatelessWidget {
  final int childCount;
  final bool expanded;
  final bool hideReplyToggle;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;

  const _PostActions({
    required this.childCount,
    required this.expanded,
    required this.hideReplyToggle,
    required this.onToggleReplies,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        TextButton.icon(
          onPressed: onReply,
          icon: const Icon(Icons.reply, size: 15),
          label: const Text('Reply'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ),
        if (childCount > 0 && !hideReplyToggle) ...[
          const SizedBox(width: 2),
          TextButton(
            onPressed: onToggleReplies,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              expanded
                  ? 'Hide $childCount ${childCount == 1 ? "reply" : "replies"}'
                  : '$childCount ${childCount == 1 ? "reply" : "replies"}',
            ),
          ),
        ],
      ],
    );
  }
}

// ── Link preview card ──────────────────────────────────────────────────────

class _LinkPreviewCard extends StatelessWidget {
  final Post post;
  const _LinkPreviewCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = post.thumbnail;
    final hasThumb = thumbnail != null && thumbnail.isNotEmpty;
    final domain = _domainOf(post.url!);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openUrl(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 400;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasThumb)
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: _thumb(theme, thumbnail),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _textContent(theme, domain),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasThumb)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _thumb(theme, thumbnail),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: _textContent(theme, domain),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _thumb(ThemeData theme, String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _textContent(ThemeData theme, String domain) {
    final title = post.title;
    final description = post.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null && title.isNotEmpty)
          Text(
            title,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.link, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                domain,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _domainOf(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  Future<void> _openUrl(BuildContext context) async {
    final url = post.url;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }
}

// ── Inline composer ────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  final PostKind kind;
  final ValueChanged<PostKind> onKindChanged;
  final TextEditingController bodyCtrl;
  final TextEditingController urlCtrl;
  final List<String> pendingFileIds;
  final VaultStore store;
  final Space space;
  final VoidCallback onAttach;
  final VoidCallback? onSend;
  final ValueChanged<String> onRemoveFile;

  const _Composer({
    required this.kind,
    required this.onKindChanged,
    required this.bodyCtrl,
    required this.urlCtrl,
    required this.pendingFileIds,
    required this.store,
    required this.space,
    required this.onAttach,
    required this.onSend,
    required this.onRemoveFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingFileIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pendingFileIds.map((id) {
                final f = store.fileById(space.id, id);
                return Chip(
                  label:
                      Text(f?.name ?? id, overflow: TextOverflow.ellipsis),
                  onDeleted: () => onRemoveFile(id),
                );
              }).toList(),
            ),
          ),
        if (kind == PostKind.bookmark)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'https://…',
                prefixIcon: Icon(Icons.link, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        TextField(
          controller: bodyCtrl,
          minLines: 1,
          maxLines: 6,
          decoration: InputDecoration(
            isDense: true,
            hintText:
                kind == PostKind.note ? 'Write something…' : 'Why save this?',
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
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
              selected: {kind},
              onSelectionChanged: (s) => onKindChanged(s.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: 'Attach',
              onPressed: onAttach,
            ),
            IconButton.filled(
              icon: const Icon(Icons.send, size: 18),
              onPressed: onSend,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Composer sheet (edit + reply) ──────────────────────────────────────────

class _ComposerResult {
  final PostKind kind;
  final String body;
  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> fileIds;
  const _ComposerResult({
    required this.kind,
    required this.body,
    required this.url,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.fileIds,
  });
}

class _ComposerSheet extends StatefulWidget {
  final VaultStore store;
  final Space space;
  final Post? editing;
  final Post? replyTo;

  const _ComposerSheet({
    required this.store,
    required this.space,
    this.editing,
    this.replyTo,
  });

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  late PostKind _kind;
  late TextEditingController _body;
  late TextEditingController _url;
  late TextEditingController _title;
  late TextEditingController _description;
  late List<String> _fileIds;
  String? _thumbnail;
  bool _fetching = false;

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
  }

  @override
  void dispose() {
    _body.dispose();
    _url.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _headerTitle {
    if (widget.editing != null) return 'Edit post';
    if (widget.replyTo != null) return 'Reply';
    return 'New post';
  }

  String get _submitLabel {
    if (widget.editing != null) return 'Save';
    if (widget.replyTo != null) return 'Reply';
    return 'Post';
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
    final ids = await _pickOrRecallFiles(context, widget.store, widget.space);
    if (!mounted || ids.isEmpty) return;
    setState(() {
      for (final id in ids) {
        if (!_fileIds.contains(id)) _fileIds.add(id);
      }
    });
  }

  Future<void> _refreshMetadata() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a URL first')),
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
    if (meta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch metadata')),
      );
    }
  }

  void _submit() {
    final url = _kind == PostKind.bookmark ? _url.text.trim() : null;
    if (_kind == PostKind.bookmark && (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A bookmark needs a URL')),
      );
      return;
    }
    Navigator.pop(
      context,
      _ComposerResult(
        kind: _kind,
        body: _body.text.trim(),
        url: url,
        title: _kind == PostKind.bookmark ? _title.text.trim() : null,
        description:
            _kind == PostKind.bookmark ? _description.text.trim() : null,
        thumbnail: _kind == PostKind.bookmark ? _thumbnail : null,
        fileIds: List.of(_fileIds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
                  child: Text(
                    'Replying to: ${_previewOf(widget.replyTo!)}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                onSelectionChanged: (s) => setState(() => _kind = s.first),
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
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
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_fileIds.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _fileIds.map((id) {
                    final f = widget.store.fileById(widget.space.id, id);
                    return Chip(
                      label: Text(f?.name ?? id,
                          overflow: TextOverflow.ellipsis),
                      onDeleted: () => setState(() => _fileIds.remove(id)),
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
    );
  }
}

// ── Shared attachment picker ───────────────────────────────────────────────

Future<List<String>> _pickOrRecallFiles(
  BuildContext context,
  VaultStore store,
  Space space,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Upload a new file'),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Recall from drive'),
            onTap: () => Navigator.pop(ctx, 'existing'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return const [];

  if (choice == 'new') {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (bytes == null || picked == null) return const [];
    final f = await store.addFileFromBytes(
      spaceId: space.id,
      bytes: bytes,
      name: picked.name,
    );
    return [f.id];
  }

  if (choice == 'existing') {
    final all = store.filesForSpace(space.id);
    if (all.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive is empty')),
        );
      }
      return const [];
    }
    return RecallFilesSheet.show(context, store, space);
  }

  return const [];
}

// ── Inline media dispatcher ────────────────────────────────────────────────

class _InlineMedia extends StatelessWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;

  const _InlineMedia({
    super.key,
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    switch (categoryFor(file.name)) {
      case FileCategory.image:
        return _InlineImage(store: store, spaceId: spaceId, file: file);
      case FileCategory.video:
        return _InlineVideo(store: store, spaceId: spaceId, file: file);
      case FileCategory.audio:
        return _InlineAudio(store: store, spaceId: spaceId, file: file);
      case FileCategory.text:
        return _InlineText(store: store, spaceId: spaceId, file: file);
      case FileCategory.pdf:
      case FileCategory.other:
        return const SizedBox.shrink();
    }
  }
}

class _InlineImage extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineImage({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineImage> createState() => _InlineImageState();
}

class _InlineImageState extends State<_InlineImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.readImageBytes(widget.spaceId, widget.file.id);
  }

  @override
  void didUpdateWidget(covariant _InlineImage old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) {
      _future = widget.store.readImageBytes(widget.spaceId, widget.file.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: snap.hasError
                  ? const Icon(Icons.broken_image_outlined)
                  : const CircularProgressIndicator(),
            ),
          );
        }
        final bytes = snap.data!;
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: InteractiveViewer(child: Image.memory(bytes)),
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 320, maxWidth: 600),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InlineVideo extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineVideo({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<_InlineVideo> {
  Player? _player;
  VideoController? _controller;
  String? _uri;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final bytes =
          await widget.store.readFileBytes(widget.spaceId, widget.file.id);
      final uri = await prepareMediaUri(bytes, widget.file.name);
      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(uri), play: false);
      if (!mounted) {
        await player.dispose();
        await releaseMediaUri(uri);
        return;
      }
      _uri = uri;
      _player = player;
      _controller = controller;
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    final uri = _uri;
    if (uri != null) releaseMediaUri(uri);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MediaErrorCard(
        file: widget.file,
        message: 'Cannot play video',
        onRetry: () {
          setState(() => _error = null);
          _init();
        },
      );
    }
    final controller = _controller;
    final player = _player;
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300,
            maxWidth: 600,
            maxHeight: 320,
          ),
          child: controller == null || player == null
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child:
                        const Center(child: CircularProgressIndicator()),
                  ),
                )
              : StreamBuilder<int?>(
                  stream: player.stream.width,
                  initialData: player.state.width,
                  builder: (context, wSnap) {
                    return StreamBuilder<int?>(
                      stream: player.stream.height,
                      initialData: player.state.height,
                      builder: (context, hSnap) {
                        final w = wSnap.data;
                        final h = hSnap.data;
                        final ratio =
                            (w != null && h != null && w > 0 && h > 0)
                                ? w / h
                                : 16.0 / 9.0;
                        return AspectRatio(
                          aspectRatio: ratio,
                          child: MaterialVideoControlsTheme(
                            normal: MaterialVideoControlsThemeData(
                              displaySeekBar: true,
                              buttonBarButtonSize: 18.0,
                              buttonBarHeight: 32.0,
                              seekBarHeight: 2.0,
                              padding: EdgeInsets.zero,
                              bottomButtonBarMargin: EdgeInsets.zero,
                              topButtonBar: const [],
                              primaryButtonBar: const [],
                              bottomButtonBar: const [
                                MaterialPlayOrPauseButton(),
                                MaterialPositionIndicator(),
                              ],
                            ),
                            fullscreen:
                                const MaterialVideoControlsThemeData(),
                            child: Video(controller: controller),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _InlineAudio extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineAudio({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineAudio> createState() => _InlineAudioState();
}

class _InlineAudioState extends State<_InlineAudio> {
  Player? _player;
  String? _uri;
  bool _loading = false;
  String? _error;

  Future<void> _start() async {
    if (_loading || _player != null) return;
    setState(() => _loading = true);
    try {
      final bytes =
          await widget.store.readFileBytes(widget.spaceId, widget.file.id);
      final uri = await prepareMediaUri(bytes, widget.file.name);
      final player = Player();
      await player.open(Media(uri));
      if (!mounted) {
        await player.dispose();
        await releaseMediaUri(uri);
        return;
      }
      _uri = uri;
      _player = player;
      setState(() => _loading = false);
      await player.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    final uri = _uri;
    if (uri != null) releaseMediaUri(uri);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MediaErrorCard(
        file: widget.file,
        message: 'Cannot play audio',
        onRetry: () => setState(() => _error = null),
      );
    }
    final player = _player;
    if (player != null) {
      return _AudioControls(player: player, file: widget.file);
    }
    return _PlayCard(
      file: widget.file,
      icon: Icons.audiotrack,
      label: 'Tap to play audio',
      loading: _loading,
      onTap: _start,
    );
  }
}

class _InlineText extends StatefulWidget {
  final VaultStore store;
  final String spaceId;
  final DriveFile file;
  const _InlineText({
    required this.store,
    required this.spaceId,
    required this.file,
  });

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  late Future<String> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _InlineText old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) {
      _future = _load();
      _expanded = false;
    }
  }

  Future<String> _load() async {
    final bytes =
        await widget.store.readFileBytes(widget.spaceId, widget.file.id);
    if (bytes.length > kMaxTextPreviewBytes) {
      return '\u0000TOO_LARGE';
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final text = snap.data!;
        if (text == '\u0000TOO_LARGE') {
          return _FileRow(
            store: widget.store,
            space: Space(
              id: widget.spaceId,
              name: '',
              icon: '',
              createdAt: DateTime.now(),
            ),
            file: widget.file,
          );
        }
        final lines = text.split('\n');
        final visibleLines =
            _expanded ? lines : lines.take(8).toList(growable: false);
        final truncated = !_expanded && lines.length > 8;
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.file.name,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_expanded ? 'Collapse' : 'Expand'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                visibleLines.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              if (truncated)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('…', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Small shared widgets ───────────────────────────────────────────────────

class _PlayCard extends StatelessWidget {
  final DriveFile file;
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PlayCard({
    required this.file,
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '$label · ${(file.sizeBytes / 1024).toStringAsFixed(1)} KB',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaErrorCard extends StatelessWidget {
  final DriveFile file;
  final String message;
  final VoidCallback onRetry;
  const _MediaErrorCard({
    required this.file,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.bodyMedium),
                Text(file.name,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _AudioControls extends StatelessWidget {
  final Player player;
  final DriveFile file;
  const _AudioControls({required this.player, required this.file});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.audiotrack, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  file.name,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StreamBuilder<Duration>(
                stream: player.stream.duration,
                initialData: player.state.duration,
                builder: (context, snap) {
                  final d = snap.data ?? Duration.zero;
                  return Text(_fmt(d), style: theme.textTheme.bodySmall);
                },
              ),
            ],
          ),
          Row(
            children: [
              StreamBuilder<bool>(
                stream: player.stream.playing,
                initialData: player.state.playing,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () =>
                        playing ? player.pause() : player.play(),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.stream.position,
                  initialData: player.state.position,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = player.state.duration;
                    final maxMs = dur.inMilliseconds
                        .clamp(1, double.infinity)
                        .toDouble();
                    final valMs = pos.inMilliseconds
                        .clamp(0, maxMs.toInt())
                        .toDouble();
                    return Slider(
                      value: valMs,
                      max: maxMs,
                      onChanged: (v) => player.seek(
                        Duration(milliseconds: v.toInt()),
                      ),
                    );
                  },
                ),
              ),
              StreamBuilder<Duration>(
                stream: player.stream.position,
                initialData: player.state.position,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(_fmt(pos),
                        style: theme.textTheme.bodySmall),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _FileRow extends StatelessWidget {
  final VaultStore store;
  final Space space;
  final DriveFile file;
  const _FileRow({
    required this.store,
    required this.space,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(file.name)),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text('${(file.sizeBytes / 1024).toStringAsFixed(1)} KB'),
      trailing: const Icon(Icons.ios_share, size: 16),
      onTap: () async {
        final bytes = await store.readFileBytes(space.id, file.id);
        await saveOrShareFile(bytes, file.name);
      },
    );
  }

  IconData _iconFor(String name) {
    switch (categoryFor(name)) {
      case FileCategory.image:
        return Icons.image;
      case FileCategory.video:
        return Icons.videocam;
      case FileCategory.audio:
        return Icons.audio_file;
      case FileCategory.text:
        return Icons.description;
      case FileCategory.pdf:
        return Icons.picture_as_pdf;
      case FileCategory.other:
        return Icons.insert_drive_file;
    }
  }
}