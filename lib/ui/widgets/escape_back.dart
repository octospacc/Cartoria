import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intercepts the ESC key on the current screen.
///
/// When [onEscape] is null, ESC calls `Navigator.maybePop()` on the
/// current route — the standard "back button" behaviour, matching what
/// a desktop user expects from ESC. When [onEscape] is provided, the
/// callback runs instead — used by screens with an intermediate mode
/// (search, selection) where ESC should exit that mode rather than
/// leave the screen entirely.
///
/// Implementation notes:
///  - Uses a `Focus` with `autofocus: true` and `onKeyEvent`, not
///    `CallbackShortcuts`. `CallbackShortcuts` only fires when a
///    *descendant* of its internal `Focus` is focused. On a fresh screen
///    with no tapped field, nothing is focused, so ESC goes to the root
///    focus node and `CallbackShortcuts` never sees it. `Focus` with
///    `autofocus: true` becomes primary on mount; when the user later
///    taps a text field, that field takes focus and ESC bubbles up to
///    this node as an ancestor — either way, ESC is caught.
///  - `ModalRoute.isCurrent` guard prevents a double-pop when a dialog
///    or bottom sheet is stacked on top. Material's `ModalBarrier`
///    handles ESC on those by default, so the underlying screen's
///    handler isn't reached. The guard is a safety net for the rare
///    race during dialog mount/unmount.
class EscapeBack extends StatefulWidget {
  final Widget child;
  final VoidCallback? onEscape;

  const EscapeBack({
    super.key,
    required this.child,
    this.onEscape,
  });

  @override
  State<EscapeBack> createState() => _EscapeBackState();
}

class _EscapeBackState extends State<EscapeBack> {
  void _handleEscape() {
    if (widget.onEscape != null) {
      widget.onEscape!();
      return;
    }
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _handleEscape();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}