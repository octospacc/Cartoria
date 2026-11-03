import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../util/html_utils.dart';
import 'attachment_picker.dart';

/// Result of the [ComposerSheet] — handed back to the feed screen, which
/// then persists it via [VaultStore.createPost] / [VaultStore.updatePost].
class ComposerResult {
  final PostKind kind;
  final String body;
  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> fileIds;

  const ComposerResult({
    required this.kind,
    required this.body,
    required this.url,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.fileIds,
  });
}

/// The inline composer at the bottom of the feed screen.
class InlineComposer extends StatelessWidget {
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

  const InlineComposer({
    super.key,
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

/// The bottom-sheet used to edit an existing post or reply to a post.
class ComposerSheet extends StatefulWidget {
  final VaultStore store;
  final Space space;
  final Post? editing;
  final Post? replyTo;

  const ComposerSheet({
    super.key,
    required this.store,
    required this.space,
    this.editing,
    this.replyTo,
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
    final ids = await pickOrRecallFiles(context, widget.store, widget.space);
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
      ComposerResult(
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