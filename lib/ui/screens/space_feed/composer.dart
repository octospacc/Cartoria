import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../util/html_utils.dart';
import 'attachment_picker.dart';

// ── Shared: date/time picker + formatter ──────────────────────────────────

Future<DateTime?> _pickPostDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final base = initial ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    helpText: 'Post date',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
    helpText: 'Post time',
  );
  if (time == null || !context.mounted) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatPostDateTime(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final month = _monthsShort[local.month - 1];
  if (local.year == now.year) {
    return '$month ${local.day}, $hh:$mm';
  }
  return '$month ${local.day} ${local.year}, $hh:$mm';
}

// ── Compose result ────────────────────────────────────────────────────────

class ComposerResult {
  final PostKind kind;
  final String body;
  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> fileIds;

  /// Only meaningful for new posts (reply or top-level). Null means
  /// "use now at send time"; ignored for edits.
  final DateTime? createdAt;

  /// The post being quoted, if this composition is a quote. Null for
  /// ordinary new posts and for replies. Ignored on edit — the existing
  /// post's quote reference is preserved by `updatePost` regardless.
  final String? quotedPostId;

  /// When true, hooks are not fired for this save. Only meaningful for
  /// create and edit actions; ignored when composing a reply or quote
  /// that reuses the previous value (currently always false for both).
  final bool skipHooks;

  const ComposerResult({
    required this.kind,
    required this.body,
    required this.url,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.fileIds,
    this.createdAt,
    this.quotedPostId,
    this.skipHooks = false,
  });
}

// ── Inline composer ───────────────────────────────────────────────────────

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

  /// Post datetime override. Null = "now at send time".
  final DateTime? postDateTime;
  final ValueChanged<DateTime?> onPostDateTimeChanged;

  final bool skipHooks;
  final ValueChanged<bool> onSkipHooksChanged;

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
    this.postDateTime,
    required this.onPostDateTimeChanged,
    this.skipHooks = false,
    required this.onSkipHooksChanged,
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
                  label: Text(f?.name ?? id, overflow: TextOverflow.ellipsis),
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
              icon:
                  Icon(skipHooks ? Icons.flash_off : Icons.flash_on, size: 20),
              tooltip: skipHooks
                  ? 'Hooks skipped this save — tap to re-enable'
                  : 'Hooks will run on save — tap to skip',
              color: skipHooks
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.primary,
              onPressed: () => onSkipHooksChanged(!skipHooks),
            ),
            _DateTimeChip(
              value: postDateTime,
              onChanged: onPostDateTimeChanged,
            ),
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
        )
      ],
    );
  }
}

// ── Compact datetime chip (inline composer) ───────────────────────────────

class _DateTimeChip extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateTimeChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value;

    if (v == null) {
      return IconButton(
        icon: const Icon(Icons.schedule),
        tooltip: 'Set post date/time',
        onPressed: () async {
          final picked = await _pickPostDateTime(context);
          if (picked != null) onChanged(picked);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final picked = await _pickPostDateTime(context, initial: v);
            if (picked != null) onChanged(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule,
                    size: 14, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 4),
                Text(
                  _formatPostDateTime(v),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onChanged(null),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close,
                        size: 12,
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Composer sheet (edit + reply) ─────────────────────────────────────────

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
    if (widget.quoting != null) return 'Quote';
    return 'New post';
  }

  String get _submitLabel {
    if (widget.editing != null) return 'Save';
    if (widget.replyTo != null) return 'Reply';
    if (widget.quoting != null) return 'Quote';
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
        createdAt: widget.editing == null ? _postDateTime : null,
        quotedPostId: widget.editing == null ? widget.quoting?.id : null,
        skipHooks: _skipHooks,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
              if (widget.editing == null) ...[
                const SizedBox(height: 12),
                _DateTimeRow(
                  value: _postDateTime,
                  onChanged: (v) => setState(() => _postDateTime = v),
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
                  onChanged: (v) => setState(() => _skipHooks = !v),
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
                      label:
                          Text(f?.name ?? id, overflow: TextOverflow.ellipsis),
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

// ── Datetime row (composer sheet) ─────────────────────────────────────────

class _DateTimeRow extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateTimeRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posted at',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  v == null ? 'Now (default)' : _formatPostDateTime(v),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (v != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Reset to now',
              onPressed: () => onChanged(null),
            ),
          TextButton(
            onPressed: () async {
              final picked = await _pickPostDateTime(context, initial: v);
              if (picked != null) onChanged(picked);
            },
            child: Text(v == null ? 'Set…' : 'Change'),
          ),
        ],
      ),
    );
  }
}
