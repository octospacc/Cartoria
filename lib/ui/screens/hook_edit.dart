import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/hooks.dart';
import '../../data/models.dart';
import '../../data/services/template.dart';
import '../../data/store.dart';

class HookEditScreen extends StatefulWidget {
  final VaultStore store;
  final Hook? existing;
  const HookEditScreen({super.key, required this.store, this.existing});

  @override
  State<HookEditScreen> createState() => _HookEditScreenState();
}

class _HookEditScreenState extends State<HookEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _key;
  late final TextEditingController _url;
  late final TextEditingController _body;
  late final TextEditingController _timeout;
  late final TextEditingController _tagFilters;

  late Set<String> _spaceIds;
  late Set<HookTrigger> _triggers;
  late Set<PostKind> _postKinds;
  late String _method;
  late List<MapEntry<TextEditingController, TextEditingController>> _headers;
  late List<_MultipartRow> _parts;

  String? _error;
  bool _saving = false;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _key = TextEditingController(text: e?.key ?? '');
    _url = TextEditingController(text: e?.urlTemplate ?? '');
    _body = TextEditingController(text: e?.bodyTemplate ?? '');
    _timeout =
        TextEditingController(text: (e?.timeoutSeconds ?? 15).toString());
    _tagFilters =
        TextEditingController(text: (e?.tagFilters ?? const {}).join(','));
    _spaceIds = {...(e?.spaceIds ?? const {})};
    _triggers = {...(e?.triggers ?? {HookTrigger.create})};
    _postKinds = {...(e?.postKinds ?? const {})};
    _method = e?.method ?? 'POST';
    _headers = (e?.headers ?? const {}).entries
        .map((entry) => MapEntry(
              TextEditingController(text: entry.key),
              TextEditingController(text: entry.value),
            ))
        .toList();
    _parts = (e?.multipartParts ?? const []).map(_MultipartRow.fromPart).toList();
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _url.dispose();
    _body.dispose();
    _timeout.dispose();
    _tagFilters.dispose();
    for (final h in _headers) {
      h.key.dispose();
      h.value.dispose();
    }
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  String _suggestKey(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty) return 'hook_${DateTime.now().millisecondsSinceEpoch}';
    if (RegExp(r'^[a-z]').hasMatch(slug)) return slug;
    return 'h_$slug';
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final name = _name.text.trim();
      if (name.isEmpty) throw ArgumentError('Name is required');
      var key = _key.text.trim();
      if (key.isEmpty) key = _suggestKey(name);
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
        throw ArgumentError(
            'Key must be lowercase letters/digits/underscore, starting '
            'with a letter');
      }
      final url = _url.text.trim();
      if (url.isEmpty) throw ArgumentError('URL is required');
      if (_triggers.isEmpty) {
        throw ArgumentError('Select at least one trigger');
      }

      final headers = <String, String>{};
      for (final h in _headers) {
        final k = h.key.text.trim();
        if (k.isEmpty) continue;
        headers[k] = h.value.text;
      }

      final tags = _tagFilters.text
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();

      final parts = <HookMultipartPart>[];
      for (final p in _parts) {
        final pname = p.name.text.trim();
        if (pname.isEmpty) continue;
        if (p.isFile) {
          final idx = int.tryParse(p.value.text.trim());
          if (idx == null || idx < 0) {
            throw ArgumentError(
                'Multipart part "$pname": file index must be 0 or greater');
          }
          parts.add(HookMultipartPart(
            name: pname,
            fileIndex: idx,
            filename: p.filename.text.trim().isEmpty
                ? null
                : p.filename.text.trim(),
          ));
        } else {
          parts.add(HookMultipartPart(
            name: pname,
            template: p.value.text,
          ));
        }
      }

      final hook = Hook(
        id: widget.existing?.id ?? const Uuid().v7(),
        key: key,
        name: name,
        enabled: widget.existing?.enabled ?? true,
        spaceIds: _spaceIds,
        triggers: _triggers,
        postKinds: _postKinds,
        tagFilters: tags,
        method: _method,
        urlTemplate: url,
        headers: headers,
        bodyTemplate:
            parts.isNotEmpty || _body.text.isEmpty ? null : _body.text,
        timeoutSeconds:
            int.tryParse(_timeout.text.trim())?.clamp(1, 120) ?? 15,
        multipartParts: parts,
      );
      await widget.store.saveHook(hook);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ArgumentError: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spaces = widget.store.spaces;
    final isNew = widget.existing == null;
    final hasMultipart = _parts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New hook' : 'Edit hook'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            decoration: const InputDecoration(
              labelText: 'Key (used in {{previous.<key>.…}})',
              helperText: 'Lowercase letters, digits, underscore. '
                  'Leave empty to auto-generate.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _label('Triggers'),
          Wrap(
            spacing: 6,
            children: HookTrigger.values.map((t) {
              return FilterChip(
                label: Text(t == HookTrigger.create ? 'On create' : 'On edit'),
                selected: _triggers.contains(t),
                onSelected: (v) => setState(() {
                  if (v) {
                    _triggers.add(t);
                  } else {
                    _triggers.remove(t);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _label('Spaces'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: spaces.map((s) {
              return FilterChip(
                label: Text('${s.icon} ${s.name}'),
                selected: _spaceIds.contains(s.id),
                onSelected: (v) => setState(() {
                  if (v) {
                    _spaceIds.add(s.id);
                  } else {
                    _spaceIds.remove(s.id);
                  }
                }),
              );
            }).toList(),
          ),
          if (_spaceIds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No spaces selected — hook runs for every space.',
                  style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 20),
          _label('Post kinds'),
          Wrap(
            spacing: 6,
            children: PostKind.values.map((k) {
              return FilterChip(
                label: Text(k == PostKind.note ? 'Notes' : 'Bookmarks'),
                selected: _postKinds.contains(k),
                onSelected: (v) => setState(() {
                  if (v) {
                    _postKinds.add(k);
                  } else {
                    _postKinds.remove(k);
                  }
                }),
              );
            }).toList(),
          ),
          if (_postKinds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'No kinds selected — matches both notes and bookmarks.',
                  style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _tagFilters,
            decoration: const InputDecoration(
              labelText: 'Tag filter (comma-separated, optional)',
              helperText: 'Runs only when the post has at least one of '
                  'these tags. Empty = any tags.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _method,
            decoration: const InputDecoration(
              labelText: 'Method',
              border: OutlineInputBorder(),
            ),
            items: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _method = v ?? 'POST'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'URL template',
              hintText: 'https://api.telegram.org/bot{{token}}/sendMessage',
              helperText: '{{expr}} is URL-encoded. {{{expr}}} is raw.',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _label('Headers'),
          ..._headers.asMap().entries.map((e) {
            final i = e.key;
            final pair = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: pair.key,
                      decoration:
                          const InputDecoration(labelText: 'Header name'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: pair.value,
                      decoration:
                          const InputDecoration(labelText: 'Value'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      pair.key.dispose();
                      pair.value.dispose();
                      _headers.removeAt(i);
                    }),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() {
              _headers.add(MapEntry(
                TextEditingController(),
                TextEditingController(),
              ));
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add header'),
          ),
          const SizedBox(height: 20),
          _label('Multipart fields (optional)'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'When present, replaces the JSON body. Each field is sent as '
              'form-data. Text parts carry templated values (e.g. caption); '
              'file parts upload a vault attachment by its 0-based index in '
              'post.fileIds.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ..._parts.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return _MultipartRowWidget(
              key: ValueKey(p.id),
              row: p,
              onRemove: () => setState(() {
                p.dispose();
                _parts.removeAt(i);
              }),
              onChanged: () => setState(() {}),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() {
              _parts.add(_MultipartRow.empty());
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add multipart field'),
          ),
          const SizedBox(height: 20),
          if (_method != 'GET' && !hasMultipart) ...[
            TextField(
              controller: _body,
              decoration: const InputDecoration(
                labelText: 'Body template',
                helperText: '{{expr}} is JSON-escaped. {{{expr}}} is raw.',
                border: OutlineInputBorder(),
              ),
              minLines: 4,
              maxLines: 12,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _timeout,
            decoration: const InputDecoration(
              labelText: 'Timeout (seconds)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(_showPreview ? Icons.expand_less : Icons.expand_more),
            label: Text(_showPreview ? 'Hide preview' : 'Preview request'),
          ),
          if (_showPreview) _buildPreview(hasMultipart),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _buildPreview(bool hasMultipart) {
    final samplePost = Post(
      id: 'preview-post',
      kind: PostKind.bookmark,
      body: '',
      url: 'https://example.com/article',
      title: 'Example title',
      description: 'Example description',
      tags: const ['tag1'],
      fileIds: const ['<file-id-0>', '<file-id-1>'],
      createdAt: DateTime.now(),
    );
    final sampleSpace = Space(
      id: 'preview-space',
      name: 'Preview space',
      icon: '📓',
      createdAt: DateTime.now(),
    );
    final previewHook = Hook(
      id: widget.existing?.id ?? 'preview',
      key: _key.text.isEmpty ? 'preview' : _key.text,
      name: _name.text.isEmpty ? 'preview' : _name.text,
      urlTemplate: _url.text,
      headers: const {},
      bodyTemplate: hasMultipart ? null : _body.text,
      multipartParts: hasMultipart
          ? _parts
              .where((p) => p.name.text.isNotEmpty)
              .map((p) => HookMultipartPart(
                    name: p.name.text.trim(),
                    template: p.isFile ? null : p.value.text,
                    fileIndex:
                        p.isFile ? int.tryParse(p.value.text) ?? 0 : null,
                  ))
              .toList()
          : const [],
    );
    final ctx = TemplateContext(
      post: samplePost,
      space: sampleSpace,
      hook: previewHook,
      trigger: HookTrigger.create,
    );

    final url = _url.text.isEmpty
        ? ''
        : TemplateRenderer.render(_url.text, ctx, escape: TemplateEscape.url);
    final headers = _headers
        .where((h) => h.key.text.isNotEmpty)
        .map((h) =>
            '${h.key.text}: ${TemplateRenderer.render(h.value.text, ctx)}')
        .join('\n');

    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
        );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('URL', style: TextStyle(fontWeight: FontWeight.w600)),
          SelectableText(url, style: mono),
          if (headers.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Headers',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SelectableText(headers, style: mono),
          ],
          if (hasMultipart) ...[
            const SizedBox(height: 8),
            const Text('Multipart',
                style: TextStyle(fontWeight: FontWeight.w600)),
            ...previewHook.multipartParts.map((p) {
              final value = p.template != null
                  ? TemplateRenderer.render(p.template!, ctx)
                  : '<file: post.fileIds[${p.fileIndex}]>';
              return SelectableText('${p.name}: $value', style: mono);
            }),
          ] else if (_body.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Body',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SelectableText(
              TemplateRenderer.render(_body.text, ctx,
                  escape: TemplateEscape.json),
              style: mono,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Multipart row model + widget ───────────────────────────────────────────

class _MultipartRow {
  final String id;
  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController filename;
  bool isFile;

  _MultipartRow({
    required this.id,
    required this.name,
    required this.value,
    required this.filename,
    required this.isFile,
  });

  factory _MultipartRow.empty() => _MultipartRow(
        id: const Uuid().v4(),
        name: TextEditingController(),
        value: TextEditingController(),
        filename: TextEditingController(),
        isFile: false,
      );

  factory _MultipartRow.fromPart(HookMultipartPart p) => _MultipartRow(
        id: const Uuid().v4(),
        name: TextEditingController(text: p.name),
        value: TextEditingController(
          text: p.template ?? (p.fileIndex?.toString() ?? '0'),
        ),
        filename: TextEditingController(text: p.filename ?? ''),
        isFile: p.fileIndex != null,
      );

  void dispose() {
    name.dispose();
    value.dispose();
    filename.dispose();
  }
}

class _MultipartRowWidget extends StatelessWidget {
  final _MultipartRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _MultipartRowWidget({
    super.key,
    required this.row,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.name,
                    decoration: const InputDecoration(
                      labelText: 'Field name',
                      hintText: 'photo, caption, chat_id, …',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Text')),
                    ButtonSegment(value: true, label: Text('File')),
                  ],
                  selected: {row.isFile},
                  onSelectionChanged: (s) {
                    row.isFile = s.first;
                    row.value.clear();
                    onChanged();
                  },
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (row.isFile) ...[
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: row.value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'File index',
                        helperText: '0-based',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.filename,
                      decoration: const InputDecoration(
                        labelText: 'Filename override (optional)',
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              TextField(
                controller: row.value,
                decoration: const InputDecoration(
                  labelText: 'Value template',
                  hintText: '{{post.title}}',
                ),
                minLines: 1,
                maxLines: 3,
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: const Text('Remove'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}