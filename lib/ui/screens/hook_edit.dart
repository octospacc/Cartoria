import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/hooks.dart';
import '../../data/models.dart';
import '../../data/services/template.dart';
import '../../data/store.dart';
import 'hook_json_editor.dart';

class HookEditScreen extends StatefulWidget {
  final VaultStore store;
  final Hook? existing;
  const HookEditScreen({super.key, required this.store, this.existing});

  @override
  State<HookEditScreen> createState() => _HookEditScreenState();
}

class _HookEditScreenState extends State<HookEditScreen> {
  late String _workingId;
  late TextEditingController _name;
  late TextEditingController _key;
  late TextEditingController _timeout;
  late TextEditingController _tagFilters;

  late Set<String> _spaceIds;
  late Set<HookTrigger> _triggers;
  late Set<PostKind> _postKinds;
  late List<_RuleRow> _rules;

  String? _error;
  bool _saving = false;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _loadFrom(widget.existing);
  }

  @override
  void dispose() {
    _disposeCurrent();
    super.dispose();
  }

  // ── State load / dispose ───────────────────────────────────────────────

  void _loadFrom(Hook? hook) {
    _workingId = hook?.id ?? const Uuid().v7();
    _name = TextEditingController(text: hook?.name ?? '');
    _key = TextEditingController(text: hook?.key ?? '');
    _timeout =
        TextEditingController(text: (hook?.timeoutSeconds ?? 15).toString());
    _tagFilters =
        TextEditingController(text: (hook?.tagFilters ?? const {}).join(','));
    _spaceIds = {...(hook?.spaceIds ?? const {})};
    _triggers = {...(hook?.triggers ?? {HookTrigger.create})};
    _postKinds = {...(hook?.postKinds ?? const {})};
    _rules = (hook?.rules ?? const [HookRule(urlTemplate: '')])
        .map(_RuleRow.fromRule)
        .toList();
  }

  void _disposeCurrent() {
    _name.dispose();
    _key.dispose();
    _timeout.dispose();
    _tagFilters.dispose();
    for (final r in _rules) {
      r.dispose();
    }
  }

  // ── JSON editor ────────────────────────────────────────────────────────

  Future<void> _openJsonEditor() async {
    final current = _buildHookForExport();
    final result = await Navigator.push<Hook>(
      context,
      MaterialPageRoute(
        builder: (_) => HookJsonEditScreen(initialHook: current),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _disposeCurrent();
      _loadFrom(result);
    });
  }

  /// Best-effort snapshot of the current form state for the JSON view.
  /// Invalid or incomplete parts are skipped rather than throwing, so the
  /// user can open JSON at any point in their editing and see what they've
  /// entered so far.
  Hook _buildHookForExport() {
    final rules = <HookRule>[];
    for (final r in _rules) {
      final rule = _buildRule(r);
      if (rule != null) rules.add(rule);
    }
    final tags = _tagFilters.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    return Hook(
      id: _workingId,
      key: _key.text.trim().isEmpty ? 'unnamed' : _key.text.trim(),
      name: _name.text.trim().isEmpty ? 'Unnamed hook' : _name.text.trim(),
      enabled: widget.existing?.enabled ?? true,
      spaceIds: _spaceIds,
      triggers: _triggers,
      postKinds: _postKinds,
      tagFilters: tags,
      rules: rules,
      timeoutSeconds: int.tryParse(_timeout.text.trim()) ?? 15,
    );
  }

  HookRule? _buildRule(_RuleRow r) {
    if (r.url.text.trim().isEmpty) return null;
    final parts = <HookMultipartPart>[];
    for (final p in r.parts) {
      final pname = p.name.text.trim();
      if (pname.isEmpty) continue;
      try {
        if (p.isFile) {
          parts.add(HookMultipartPart(
            name: pname,
            filePath: p.value.text.trim(),
            filename: p.filename.text.trim().isEmpty
                ? null
                : p.filename.text.trim(),
            repeat: p.repeat ? 'post.files' : null,
            join: p.repeat && p.join.text.isNotEmpty ? p.join.text : null,
            prefix: p.repeat && p.prefix.text.isNotEmpty
                ? p.prefix.text
                : null,
            suffix: p.repeat && p.suffix.text.isNotEmpty
                ? p.suffix.text
                : null,
          ));
        } else {
          parts.add(HookMultipartPart(
            name: pname,
            template: p.value.text,
            repeat: p.repeat ? 'post.files' : null,
            join: p.repeat && p.join.text.isNotEmpty ? p.join.text : null,
            prefix: p.repeat && p.prefix.text.isNotEmpty
                ? p.prefix.text
                : null,
            suffix: p.repeat && p.suffix.text.isNotEmpty
                ? p.suffix.text
                : null,
          ));
        }
      } catch (_) {
        // Skip malformed parts during export; the user will see they're
        // missing and can fix the form.
      }
    }
    final headers = <String, String>{};
    for (final h in r.headers) {
      final hk = h.key.text.trim();
      if (hk.isEmpty) continue;
      headers[hk] = h.value.text;
    }
    return HookRule(
      when: r.when.text.trim().isEmpty ? null : r.when.text.trim(),
      method: r.method,
      urlTemplate: r.url.text.trim(),
      headers: headers,
      bodyTemplate:
          parts.isNotEmpty || r.body.text.isEmpty ? null : r.body.text,
      multipartParts: parts,
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────

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
            'Key must be lowercase letters/digits/underscore');
      }
      if (_triggers.isEmpty) {
        throw ArgumentError('Select at least one trigger');
      }
      if (_rules.isEmpty) {
        throw ArgumentError('Add at least one rule');
      }

      final rules = <HookRule>[];
      for (var i = 0; i < _rules.length; i++) {
        final r = _rules[i];
        if (r.url.text.trim().isEmpty) {
          throw ArgumentError('Rule ${i + 1}: URL is required');
        }
        final built = _buildRule(r);
        if (built == null) {
          throw ArgumentError('Rule ${i + 1}: could not be built');
        }
        rules.add(built);
      }

      final tags = _tagFilters.text
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();

      final hook = Hook(
        id: _workingId,
        key: key,
        name: name,
        enabled: widget.existing?.enabled ?? true,
        spaceIds: _spaceIds,
        triggers: _triggers,
        postKinds: _postKinds,
        tagFilters: tags,
        rules: rules,
        timeoutSeconds:
            int.tryParse(_timeout.text.trim())?.clamp(1, 120) ?? 15,
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

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final spaces = widget.store.spaces;
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New hook' : 'Edit hook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Edit as JSON',
            onPressed: _openJsonEditor,
          ),
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
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
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
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _section('Triggers'),
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
          _section('Spaces'),
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
          const SizedBox(height: 20),
          _section('Post kinds'),
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
          const SizedBox(height: 20),
          TextField(
            controller: _tagFilters,
            decoration: const InputDecoration(
              labelText: 'Tag filter (comma-separated, optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _timeout,
            decoration: const InputDecoration(
              labelText: 'Timeout (seconds)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          _section('Rules'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'The first rule whose "when" evaluates true fires. An empty '
              '"when" always matches.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ..._rules.asMap().entries.map((e) => _RuleCard(
                key: ValueKey(e.value.id),
                index: e.key,
                row: e.value,
                canDelete: _rules.length > 1,
                onChanged: () => setState(() {}),
                onDelete: () => setState(() {
                  e.value.dispose();
                  _rules.removeAt(e.key);
                }),
              )),
          TextButton.icon(
            onPressed: () => setState(() {
              _rules.add(_RuleRow.empty());
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add rule'),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(_showPreview ? Icons.expand_less : Icons.expand_more),
            label: Text(_showPreview ? 'Hide preview' : 'Preview request'),
          ),
          if (_showPreview) _buildPreview(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _buildPreview() {
    final built = _buildHookForExport();
    final samplePost = Post(
      id: 'preview-post',
      kind: PostKind.bookmark,
      body: '',
      url: 'https://example.com/article',
      title: 'Example title',
      tags: const ['tag1'],
      fileIds: const [],
      createdAt: DateTime.now(),
    );
    final sampleSpace = Space(
      id: 'preview-space',
      name: 'Preview space',
      icon: '📓',
      createdAt: DateTime.now(),
    );
    final ctx = TemplateContext(
      post: samplePost,
      space: sampleSpace,
      hook: built,
      trigger: HookTrigger.create,
      files: const [],
    );
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
        );
    final sections = <Widget>[];
    if (built.rules.isEmpty) {
      sections.add(const Text('No complete rules to preview yet.'));
    }
    for (var i = 0; i < built.rules.length; i++) {
      final rule = built.rules[i];
      String url;
      try {
        url = TemplateRenderer.render(rule.urlTemplate, ctx,
            escape: TemplateEscape.url);
      } catch (e) {
        url = '<render error: $e>';
      }
      sections.add(Text('Rule ${i + 1} — ${rule.when ?? "always"}',
          style: Theme.of(context).textTheme.titleSmall));
      sections.add(SelectableText('${rule.method} $url', style: mono));
      if (rule.multipartParts.isNotEmpty) {
        sections.add(SelectableText(
            '(multipart: ${rule.multipartParts.length} part'
            '${rule.multipartParts.length == 1 ? "" : "s"})',
            style: mono));
      } else if (rule.bodyTemplate != null && rule.bodyTemplate!.isNotEmpty) {
        try {
          final body = TemplateRenderer.render(rule.bodyTemplate!, ctx,
              escape: TemplateEscape.json);
          sections.add(SelectableText(body, style: mono));
        } catch (e) {
          sections.add(SelectableText('<render error: $e>', style: mono));
        }
      }
      sections.add(const SizedBox(height: 10));
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }
}

// ── Rule row model ─────────────────────────────────────────────────────────

class _RuleRow {
  final String id;
  final TextEditingController when;
  final TextEditingController url;
  final TextEditingController body;
  String method;
  final List<_PartRow> parts;
  final List<MapEntry<TextEditingController, TextEditingController>> headers;

  _RuleRow({
    required this.id,
    required this.when,
    required this.url,
    required this.body,
    required this.method,
    required this.parts,
    required this.headers,
  });

  factory _RuleRow.empty() => _RuleRow(
        id: const Uuid().v4(),
        when: TextEditingController(),
        url: TextEditingController(),
        body: TextEditingController(),
        method: 'POST',
        parts: [],
        headers: [],
      );

  factory _RuleRow.fromRule(HookRule r) => _RuleRow(
        id: const Uuid().v4(),
        when: TextEditingController(text: r.when ?? ''),
        url: TextEditingController(text: r.urlTemplate),
        body: TextEditingController(text: r.bodyTemplate ?? ''),
        method: r.method,
        parts: r.multipartParts.map(_PartRow.fromPart).toList(),
        headers: r.headers.entries
            .map((e) => MapEntry(
                  TextEditingController(text: e.key),
                  TextEditingController(text: e.value),
                ))
            .toList(),
      );

  void dispose() {
    when.dispose();
    url.dispose();
    body.dispose();
    for (final p in parts) {
      p.dispose();
    }
    for (final h in headers) {
      h.key.dispose();
      h.value.dispose();
    }
  }
}

class _PartRow {
  final String id;
  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController filename;
  final TextEditingController join;
  final TextEditingController prefix;
  final TextEditingController suffix;
  bool isFile;
  bool repeat;

  _PartRow({
    required this.id,
    required this.name,
    required this.value,
    required this.filename,
    required this.join,
    required this.prefix,
    required this.suffix,
    required this.isFile,
    required this.repeat,
  });

  factory _PartRow.empty() => _PartRow(
        id: const Uuid().v4(),
        name: TextEditingController(),
        value: TextEditingController(),
        filename: TextEditingController(),
        join: TextEditingController(),
        prefix: TextEditingController(),
        suffix: TextEditingController(),
        isFile: false,
        repeat: false,
      );

  factory _PartRow.fromPart(HookMultipartPart p) => _PartRow(
        id: const Uuid().v4(),
        name: TextEditingController(text: p.name),
        value: TextEditingController(text: p.template ?? p.filePath ?? ''),
        filename: TextEditingController(text: p.filename ?? ''),
        join: TextEditingController(text: p.join ?? ''),
        prefix: TextEditingController(text: p.prefix ?? ''),
        suffix: TextEditingController(text: p.suffix ?? ''),
        isFile: p.filePath != null,
        repeat: p.repeat != null,
      );

  void dispose() {
    name.dispose();
    value.dispose();
    filename.dispose();
    join.dispose();
    prefix.dispose();
    suffix.dispose();
  }
}

// ── Rule card ──────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final int index;
  final _RuleRow row;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _RuleCard({
    super.key,
    required this.index,
    required this.row,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasParts = row.parts.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Rule ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.when,
              decoration: const InputDecoration(
                labelText: 'When (optional)',
                hintText: 'post.files.length >= 2 && post.files.length <= 10',
                helperText: 'First rule whose condition is true fires. '
                    'Empty always matches.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    value: row.method,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      row.method = v ?? 'POST';
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.url,
                    decoration: const InputDecoration(
                      labelText: 'URL template',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.body,
              enabled: !hasParts,
              decoration: InputDecoration(
                labelText: hasParts
                    ? 'Body template (disabled — multipart in use)'
                    : 'Body template',
                border: const OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            _header(context, 'Headers'),
            ...row.headers.asMap().entries.map((e) {
              final i = e.key;
              final pair = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pair.key,
                        decoration:
                            const InputDecoration(labelText: 'Name'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: pair.value,
                        decoration:
                            const InputDecoration(labelText: 'Value'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        pair.key.dispose();
                        pair.value.dispose();
                        row.headers.removeAt(i);
                        onChanged();
                      },
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  row.headers.add(MapEntry(
                    TextEditingController(),
                    TextEditingController(),
                  ));
                  onChanged();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add header'),
              ),
            ),
            const SizedBox(height: 12),
            _header(context, 'Multipart parts'),
            ...row.parts.asMap().entries.map((e) {
              final i = e.key;
              return _PartCard(
                key: ValueKey(e.value.id),
                row: e.value,
                onChanged: onChanged,
                onDelete: () {
                  e.value.dispose();
                  row.parts.removeAt(i);
                  onChanged();
                },
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  row.parts.add(_PartRow.empty());
                  onChanged();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add part'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
      );
}

// ── Part card ──────────────────────────────────────────────────────────────

class _PartCard extends StatelessWidget {
  final _PartRow row;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _PartCard({
    super.key,
    required this.row,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.name,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'chat_id, caption, photo, media…',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Text')),
                    ButtonSegment(value: true, label: Text('File')),
                  ],
                  selected: {row.isFile},
                  onSelectionChanged: (s) {
                    row.isFile = s.first;
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
            const SizedBox(height: 6),
            TextField(
              controller: row.value,
              decoration: InputDecoration(
                labelText: row.isFile
                    ? 'File path (e.g. post.files.0.id or repeat.file.id)'
                    : 'Value template',
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Repeat over post.files'),
              value: row.repeat,
              onChanged: (v) {
                row.repeat = v;
                onChanged();
              },
            ),
            if (row.repeat)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.join,
                      decoration: const InputDecoration(
                        labelText: 'Join (optional)',
                        hintText: ',',
                        helperText: 'If set, iterations merge into one field',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: row.prefix,
                      decoration: const InputDecoration(labelText: 'Prefix'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: row.suffix,
                      decoration: const InputDecoration(labelText: 'Suffix'),
                    ),
                  ),
                ],
              ),
            if (row.isFile && !row.repeat)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextField(
                  controller: row.filename,
                  decoration: const InputDecoration(
                    labelText: 'Filename override (optional)',
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
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