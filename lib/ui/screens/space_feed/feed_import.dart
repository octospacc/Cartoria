part of '../space_feed.dart';

/// Best-effort user-facing message from an exception thrown during an
/// import. Strips the common `ExceptionName: ` prefixes so snackbars
/// and dialogs show the meaningful text without noise.
String _friendlyError(Object e) {
  final s = e.toString();
  const prefixes = [
    'FormatException: ',
    'Exception: ',
    'StateError: ',
    'ArgumentError: ',
  ];
  for (final p in prefixes) {
    if (s.startsWith(p)) return s.substring(p.length);
  }
  return s;
}

class _PastePostSourceDialog extends StatefulWidget {
  final VaultStore store;
  final String spaceId;

  const _PastePostSourceDialog({
    required this.store,
    required this.spaceId,
  });

  @override
  State<_PastePostSourceDialog> createState() =>
      _PastePostSourceDialogState();
}

class _PastePostSourceDialogState extends State<_PastePostSourceDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final post = await widget.store.importPostFromSource(
        spaceId: widget.spaceId,
        source: _ctrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyError(e);
      });
    }
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
      child: AlertDialog(
        title: Text(l.feedPasteDialogTitle),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  l.feedPasteDialogHint,
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
                  child: SelectableText(
                    _error!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              SizedBox(
                height: 300,
                child: TextField(
                  controller: _ctrl,
                  enabled: !_busy,
                  maxLines: null,
                  expands: true,
                  style: mono,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '<!---\n'
                        '{\n'
                        '  "kind": "note",\n'
                        '  "created": "2026-01-15T12:00:00.000Z"\n'
                        '}\n'
                        '--->\n'
                        '\n'
                        '<p>Hello</p>',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: _busy ? null : _import,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.commonImport),
          ),
        ],
      ),
    );
  }
}