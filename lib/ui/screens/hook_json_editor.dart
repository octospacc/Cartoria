import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../data/hooks.dart';
import '../../l10n/l10n.dart';
import '../widgets/escape_back.dart';

class HookJsonEditScreen extends StatefulWidget {
  final Hook initialHook;
  const HookJsonEditScreen({super.key, required this.initialHook});

  @override
  State<HookJsonEditScreen> createState() => _HookJsonEditScreenState();
}

class _HookJsonEditScreenState extends State<HookJsonEditScreen> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ')
          .convert(widget.initialHook.toJson()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _format() {
    final l = context.l10n;
    setState(() {
      _error = null;
      try {
        final parsed = jsonDecode(_ctrl.text);
        _ctrl.text = const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (e) {
        _error = l.hookJsonErrParse(e.toString());
      }
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _ctrl.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.hookJsonCopied)),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null) return;
    setState(() {
      _ctrl.text = text;
      _error = null;
    });
  }

  void _apply() {
    final l = context.l10n;
    setState(() {
      _error = null;
      try {
        final raw = jsonDecode(_ctrl.text);
        if (raw is! Map<String, dynamic>) {
          _error = l.hookJsonErrTopLevel;
          return;
        }
        final withId = <String, dynamic>{
          ...raw,
          'id': (raw['id'] as String?) ?? const Uuid().v7(),
        };
        final hook = Hook.fromJson(withId);
        Navigator.pop(context, hook);
      } catch (e) {
        _error = l.hookJsonErrInvalid(e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
    );

    return EscapeBack(
        child: Scaffold(
      appBar: AppBar(
        title: Text(l.hookJsonTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: l.hookJsonCopy,
            onPressed: _copy,
          ),
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: l.hookJsonPaste,
            onPressed: _paste,
          ),
          IconButton(
            icon: const Icon(Icons.format_align_left),
            tooltip: l.hookJsonFormat,
            onPressed: _format,
          ),
          TextButton(
            onPressed: _apply,
            child: Text(l.hookJsonApply),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
                l.hookJsonHelper,
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
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                style: mono,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}