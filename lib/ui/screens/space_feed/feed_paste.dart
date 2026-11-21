part of '../space_feed.dart';

extension _FeedPasteExt on _SpaceFeedScreenState {
  Future<void> _onPastedFiles(List<ClipboardFile> files) async {
    if (files.isEmpty || !mounted) return;
    final newIds = <String>[];
    for (final f in files) {
      try {
        final file = await widget.store.addFileFromBytes(
          spaceId: widget.space.id,
          bytes: f.bytes,
          name: f.name,
        );
        newIds.add(file.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.attachmentPasteFailed(e.toString())),
            ),
          );
        }
      }
    }
    if (mounted && newIds.isNotEmpty) {
      _setStateSafe(() {
        for (final id in newIds) {
          if (!_pendingFileIds.contains(id)) _pendingFileIds.add(id);
        }
      });
    }
  }

  Widget _withPasteShortcut(Widget child) {
    if (kIsWeb) return child;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final hk = HardwareKeyboard.instance;
        final isMac = defaultTargetPlatform == TargetPlatform.macOS;
        final mod = isMac ? hk.isMetaPressed : hk.isControlPressed;
        if (!mod || event.logicalKey != LogicalKeyboardKey.keyV) {
          return KeyEventResult.ignored;
        }
        _handlePasteShortcut();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

  Future<void> _handlePasteShortcut() async {
    final files = await readClipboardFiles();
    if (!mounted) return;
    if (files.isNotEmpty) {
      await _onPastedFiles(files);
      return;
    }
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (ctx != null) {
      await Actions.maybeInvoke(
        ctx,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    }
  }
}