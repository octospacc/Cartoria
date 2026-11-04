import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../data/hooks.dart';

/// Full-screen JSON view/edit for a [Hook].
///
/// Opened from [HookEditScreen]; returns the parsed [Hook] to the caller
/// on Apply, or `null` on back/cancel.
///
/// The screen never persists anything itself — it hands the resulting
/// [Hook] back to the caller, which decides whether to swap the form
/// state or save directly.
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
    setState(() {
      _error = null;
      try {
        final parsed = jsonDecode(_ctrl.text);
        _ctrl.text = const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (e) {
        _error = 'Not valid JSON: $e';
      }
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _ctrl.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
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
    setState(() {
      _error = null;
      try {
        final raw = jsonDecode(_ctrl.text);
        if (raw is! Map<String, dynamic>) {
          _error = 'Top-level JSON value must be an object';
          return;
        }
        // The `id` field is internal (never user-visible in the form).
        // Inject one when omitted so AI-generated or hand-written JSON
        // works without the user having to invent UUIDs.
        final withId = <String, dynamic>{
          ...raw,
          'id': (raw['id'] as String?) ?? const Uuid().v7(),
        };
        final hook = Hook.fromJson(withId);
        Navigator.pop(context, hook);
      } catch (e) {
        _error = 'Invalid hook JSON: $e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hook JSON'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy',
            onPressed: _copy,
          ),
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: 'Paste',
            onPressed: _paste,
          ),
          IconButton(
            icon: const Icon(Icons.format_align_left),
            tooltip: 'Format',
            onPressed: _format,
          ),
          TextButton(
            onPressed: _apply,
            child: const Text('Apply'),
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
                'Edit this hook as JSON. Useful for pasting AI-generated '
                'hooks or moving a hook to another vault. The "id" field '
                'is internal — leave it alone, or omit it to generate a '
                'new one on Apply.',
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
    );
  }
}