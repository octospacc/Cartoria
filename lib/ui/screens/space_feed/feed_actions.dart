part of '../space_feed.dart';

extension _FeedActionsExt on _SpaceFeedScreenState {
  Future<void> _editSpace() async {
    final l = context.l10n;
    final result = await showSpaceDialog(
      context,
      initialName: _space.name,
      initialIcon: _space.icon,
      title: l.spaceDialogEditTitle,
      confirmLabel: l.commonSave,
    );
    if (result == null) return;
    await widget.store.updateSpace(
      widget.space.id,
      name: result.name,
      icon: result.icon,
    );
  }

  Future<void> _importFile() async {
    final l = context.l10n;
    final picked = await pickImportFiles(context);
    if (picked.isEmpty) return;

    final summaries = <String>[];
    final errors = <String>[];
    var ok = 0;
    var failed = 0;

    for (final p in picked) {
      final result = await _importOneFile(p);
      if (result.error != null) {
        failed++;
        errors.add('${p.name}: ${result.error}');
      } else {
        ok++;
        final s = result.summary;
        if (s != null && s.isNotEmpty) summaries.add(s);
      }
    }

    if (!mounted) return;

    final String message;
    if (picked.length == 1 && ok == 1 && summaries.isNotEmpty) {
      message = summaries.first;
    } else {
      final parts = <String>[];
      if (ok > 0) parts.add(l.feedImportFilesSummary(ok));
      if (failed > 0) parts.add(l.spaceImportSummaryFailed(failed));
      message = parts.isEmpty ? l.spaceImportNothing : parts.join(' · ');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: failed > 0
            ? SnackBarAction(
                label: l.spaceImportDetails,
                onPressed: () => showImportErrors(context, errors),
              )
            : null,
      ),
    );
  }

  Future<({String? summary, String? error})> _importOneFile(
    ({Uint8List bytes, String name}) p,
  ) async {
    final l = context.l10n;
    final lower = p.name.toLowerCase();
    try {
      if (lower.endsWith('.zip')) {
        final r = await widget.store.importSpaceZipIntoExistingSpace(
          targetSpaceId: widget.space.id,
          zipBytes: p.bytes,
        );
        return (summary: spaceImportSummary(context, r), error: null);
      }
      if (lower.endsWith('.html') || lower.endsWith('.htm')) {
        final text = utf8.decode(p.bytes, allowMalformed: true);
        if (text.trimLeft().startsWith('<!---')) {
          await widget.store.importPostFromSource(
            spaceId: widget.space.id,
            source: text,
          );
          return (summary: l.feedImportPost, error: null);
        }
        final file = BookmarkFileParser.parse(text);
        if (file.bookmarks.isEmpty) {
          return (summary: null, error: l.feedImportBookmarksFound);
        }
        final r = await widget.store.importBookmarksIntoSpace(
          spaceId: widget.space.id,
          file: file,
        );
        return (summary: bookmarkImportSummary(context, r), error: null);
      }
      return (summary: null, error: l.feedUnsupportedFile);
    } catch (e) {
      return (summary: null, error: friendlyError(e));
    }
  }

  Future<void> _pastePostSource() async {
    final l = context.l10n;
    final post = await showDialog<Post>(
      context: context,
      builder: (_) => _PastePostSourceDialog(
        store: widget.store,
        spaceId: widget.space.id,
      ),
    );
    if (post == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.feedImportPost)),
    );
  }

  Future<void> _deleteSpace() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.spacesDeleteTitle(_space.name)),
        content: Text(l.spacesDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteSpace(widget.space.id);
      if (mounted) Navigator.pop(context);
    }
  }
}