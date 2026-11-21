library hook_edit;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/hooks.dart';
import '../../data/models.dart';
import '../../data/services/template.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../widgets/escape_back.dart';
import 'hook_json_editor.dart';

part 'hook_edit_rules.dart';
part 'hook_edit_parts.dart';
part 'hook_edit_vars.dart';

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
  late List<_VarRow> _variables;

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

  void _loadFrom(Hook? hook) {
    _workingId = hook?.id ?? const Uuid().v7();
    _name = TextEditingController(text: hook?.name ?? '');
    _key = TextEditingController(text: hook?.key ?? '');
    _timeout =
        TextEditingController(text: (hook?.timeoutSeconds ?? 15).toString());
    _tagFilters =
        TextEditingController(text: (hook?.tagFilters ?? const {}).join(','));
    _spaceIds = {...(hook?.spaceIds ?? const {})};
    _triggers = {
      ...(hook?.triggers ?? {HookTrigger.create})
    };
    _postKinds = {...(hook?.postKinds ?? const {})};
    _rules = (hook?.rules ?? const [HookRule(urlTemplate: '')])
        .map(_RuleRow.fromRule)
        .toList();
    _variables = (hook?.variables ?? const <String, String>{})
        .entries
        .map((e) => _VarRow.fromEntry(e.key, e.value))
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
    for (final v in _variables) {
      v.dispose();
    }
  }

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

  Map<String, String> _collectVariables() {
    final out = <String, String>{};
    for (final v in _variables) {
      final name = v.name.text.trim();
      if (name.isEmpty) continue;
      out[name] = v.value.text;
    }
    return out;
  }

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
      key: _key.text.trim().isEmpty
          ? context.l10n.hookEditFallbackKey
          : _key.text.trim(),
      name: _name.text.trim().isEmpty
          ? context.l10n.hookEditFallbackName
          : _name.text.trim(),
      enabled: widget.existing?.enabled ?? true,
      spaceIds: _spaceIds,
      triggers: _triggers,
      postKinds: _postKinds,
      tagFilters: tags,
      rules: rules,
      variables: _collectVariables(),
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
            filename:
                p.filename.text.trim().isEmpty ? null : p.filename.text.trim(),
            repeat: p.repeat ? 'post.files' : null,
            join: p.repeat && p.join.text.isNotEmpty ? p.join.text : null,
            prefix: p.repeat && p.prefix.text.isNotEmpty ? p.prefix.text : null,
            suffix: p.repeat && p.suffix.text.isNotEmpty ? p.suffix.text : null,
          ));
        } else {
          parts.add(HookMultipartPart(
            name: pname,
            template: p.value.text,
            repeat: p.repeat ? 'post.files' : null,
            join: p.repeat && p.join.text.isNotEmpty ? p.join.text : null,
            prefix: p.repeat && p.prefix.text.isNotEmpty ? p.prefix.text : null,
            suffix: p.repeat && p.suffix.text.isNotEmpty ? p.suffix.text : null,
          ));
        }
      } catch (_) {
        // Skip malformed parts during export.
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

  String _suggestKey(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty) return 'hook_${DateTime.now().millisecondsSinceEpoch}';
    if (RegExp(r'^[a-z]').hasMatch(slug)) return slug;
    return 'h_$slug';
  }

  String _stripError(Object e) {
    final s = e.toString();
    const prefixes = [
      'FormatException: ',
      'ArgumentError: ',
      'Invalid argument(s): ',
      'StateError: ',
    ];
    for (final p in prefixes) {
      if (s.startsWith(p)) return s.substring(p.length);
    }
    return s;
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    final l = context.l10n;
    try {
      final name = _name.text.trim();
      if (name.isEmpty) throw FormatException(l.hookEditErrNameRequired);
      var key = _key.text.trim();
      if (key.isEmpty) key = _suggestKey(name);
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
        throw FormatException(l.hookEditErrKeyFormat);
      }
      if (_triggers.isEmpty) {
        throw FormatException(l.hookEditErrTriggers);
      }
      if (_rules.isEmpty) {
        throw FormatException(l.hookEditErrRules);
      }

      final rules = <HookRule>[];
      for (var i = 0; i < _rules.length; i++) {
        final r = _rules[i];
        if (r.url.text.trim().isEmpty) {
          throw FormatException(l.hookEditErrRuleUrl(i + 1));
        }
        final built = _buildRule(r);
        if (built == null) {
          throw FormatException(l.hookEditErrRuleBuild(i + 1));
        }
        rules.add(built);
      }

      final tags = _tagFilters.text
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();

      final seenNames = <String>{};
      for (var i = 0; i < _variables.length; i++) {
        final v = _variables[i];
        final vName = v.name.text.trim();
        if (vName.isEmpty) continue;
        if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(vName)) {
          throw FormatException(l.hookEditErrVarNameFormat(i + 1));
        }
        if (!seenNames.add(vName)) {
          throw FormatException(l.hookEditErrVarDup(i + 1, vName));
        }
      }
      final variables = _collectVariables();

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
        variables: variables,
        timeoutSeconds: int.tryParse(_timeout.text.trim())?.clamp(1, 120) ?? 15,
      );
      await widget.store.saveHook(hook);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = _stripError(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spaces = widget.store.spaces;
    final isNew = widget.existing == null;
    final l = context.l10n;

    return EscapeBack(
        child: Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l.hookEditNew : l.hookEditExisting),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: l.hookEditOpenJson,
            onPressed: _openJsonEditor,
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l.hookEditSave),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l.hookEditNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            decoration: InputDecoration(
              labelText: l.hookEditKeyLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _section(l.hookEditSectionTriggers),
          Wrap(
            spacing: 6,
            children: HookTrigger.values.map((t) {
              return FilterChip(
                label: Text(t == HookTrigger.create
                    ? l.hookEditOnCreate
                    : l.hookEditOnEdit),
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
          _section(l.hookEditSectionSpaces),
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
          _section(l.hookEditSectionPostKinds),
          Wrap(
            spacing: 6,
            children: PostKind.values.map((k) {
              return FilterChip(
                label: Text(k == PostKind.note
                    ? l.hookEditPostKindNote
                    : l.hookEditPostKindBookmark),
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
            decoration: InputDecoration(
              labelText: l.hookEditTagFilterLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _timeout,
            decoration: InputDecoration(
              labelText: l.hookEditTimeoutLabel,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          _section(l.hookEditSectionVariables),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.hookEditVariablesHelper,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          ..._variables.asMap().entries.map((e) => _VariableRow(
                key: ValueKey(e.value.id),
                row: e.value,
                onChanged: () => setState(() {}),
                onDelete: () => setState(() {
                  e.value.dispose();
                  _variables.removeAt(e.key);
                }),
              )),
          TextButton.icon(
            onPressed: () => setState(() {
              _variables.add(_VarRow.empty());
            }),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.hookEditAddVariable),
          ),
          const SizedBox(height: 24),
          _section(l.hookEditSectionRules),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.hookEditRulesHelper,
              style: const TextStyle(fontSize: 12),
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
            label: Text(l.hookEditAddRule),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _showPreview = !_showPreview),
            icon: Icon(_showPreview ? Icons.expand_less : Icons.expand_more),
            label: Text(_showPreview
                ? l.hookEditHidePreview
                : l.hookEditShowPreview),
          ),
          if (_showPreview) _buildPreview(l),
          const SizedBox(height: 40),
        ],
      ),
    ));
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _buildPreview(AppLocalizations l) {
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
      sections.add(Text(l.hookEditPreviewEmpty));
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
      sections.add(Text(
          l.hookEditPreviewRuleTitle(i + 1, rule.when ?? l.hookPreviewAlways),
          style: Theme.of(context).textTheme.titleSmall));
      sections.add(SelectableText('${rule.method} $url', style: mono));
      if (rule.multipartParts.isNotEmpty) {
        sections.add(SelectableText(
            l.hookEditPreviewMultipart(rule.multipartParts.length),
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