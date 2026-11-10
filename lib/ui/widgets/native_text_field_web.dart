import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Native HTML `<textarea>` embedded in Flutter's view tree.
///
/// Bypasses Flutter's text-input bridge, which has documented bugs on
/// iOS Safari where tapping inside a scrolled multi-line field places
/// the cursor in the wrong position, and where long-pressing the
/// selection caret leaves the field unresponsive. A real `<textarea>`
/// gets the browser's well-tested native editing behavior instead.
///
/// Text is synchronized bidirectionally with [controller]. The native
/// element is the source of truth for user input; external controller
/// changes (e.g. from edit mode prefilling) propagate to the element.
class NativeTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final TextStyle? style;

  const NativeTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.minLines = 1,
    this.maxLines = 6,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.style,
  });

  @override
  State<NativeTextField> createState() => _NativeTextFieldState();
}

class _NativeTextFieldState extends State<NativeTextField> {
  late final String _viewId;
  web.HTMLTextAreaElement? _textarea;
  late String _lastKnownText;
  double? _measuredHeight;

  FocusNode? _internalFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  static const double _lineHeight = 22.0;
  static const double _verticalPadding = 24.0;

  static const String _cssClass = 'cartoria-native-textarea';
  static bool _cssInjected = false;

  @override
  void initState() {
    super.initState();
    _lastKnownText = widget.controller.text;
    _viewId = 'cartoria-textarea-'
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${identityHashCode(this)}';

    _focusNode.addListener(_syncDomFocus);

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      _ensureCssInjected();
      final ta = web.HTMLTextAreaElement()
        ..className = _cssClass
        ..value = widget.controller.text
        ..placeholder = widget.hintText ?? ''
        ..spellcheck = true
        ..autocapitalize = 'sentences';

      _applySizing(ta);
      _wireEvents(ta);
      _textarea = ta;

      if (widget.autofocus) {
        Future.microtask(() {
          try {
            ta.focus();
          } catch (_) {}
        });
      }
      return ta;
    });
  }

  void _ensureCssInjected() {
    if (_cssInjected) return;
    if (web.document.getElementById('cartoria-native-textarea-style') !=
        null) {
      _cssInjected = true;
      return;
    }
    final style = web.HTMLStyleElement()
      ..id = 'cartoria-native-textarea-style'
      ..textContent = '''
        .$_cssClass {
          width: 100%;
          padding: 12px;
          border: 1px solid rgba(121, 116, 126, 0.55);
          border-radius: 8px;
          background: transparent;
          color: #1C1B1F;
          font-family: inherit;
          font-size: 16px;
          line-height: 1.375;
          outline: none;
          resize: none;
          overflow-y: auto;
          box-sizing: border-box;
          -webkit-appearance: none;
        }
        .$_cssClass:focus {
          border-color: #A0432B;
        }
        .$_cssClass::placeholder {
          color: rgba(0, 0, 0, 0.42);
        }
        @media (prefers-color-scheme: dark) {
          .$_cssClass {
            color: #E6E1E5;
            border-color: rgba(200, 200, 200, 0.3);
          }
          .$_cssClass:focus {
            border-color: #FFB4A2;
          }
          .$_cssClass::placeholder {
            color: rgba(255, 255, 255, 0.42);
          }
        }
      ''';
    web.document.head?.append(style);
    _cssInjected = true;
  }

  void _applySizing(web.HTMLTextAreaElement ta) {
    ta.style
      ..minHeight = '${widget.minLines * _lineHeight + _verticalPadding}px'
      ..maxHeight = widget.maxLines == null
          ? 'none'
          : '${widget.maxLines! * _lineHeight + _verticalPadding}px';
  }

  void _wireEvents(web.HTMLTextAreaElement ta) {
    ta.addEventListener(
      'input',
      ((web.Event e) {
        final text = ta.value;
        if (text != _lastKnownText) {
          _lastKnownText = text;
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          widget.onChanged?.call(text);
        }
        _autoResize();
      }).toJS,
    );

    ta.addEventListener(
      'focus',
      ((web.Event e) {
        if (!_focusNode.hasFocus) _focusNode.requestFocus();
      }).toJS,
    );

    ta.addEventListener(
      'blur',
      ((web.Event e) {
        if (_focusNode.hasFocus) _focusNode.unfocus();
      }).toJS,
    );

    ta.addEventListener(
      'keydown',
      ((web.Event e) {
        final ke = e as web.KeyboardEvent;
        if (ke.key == 'Enter' && (ke.metaKey || ke.ctrlKey)) {
          ke.preventDefault();
          widget.onSubmitted?.call();
        }
      }).toJS,
    );
  }

  void _syncDomFocus() {
    final ta = _textarea;
    if (ta == null) return;
    final domFocused = web.document.activeElement == ta;
    if (_focusNode.hasFocus && !domFocused) {
      try {
        ta.focus();
      } catch (_) {}
    } else if (!_focusNode.hasFocus && domFocused) {
      try {
        ta.blur();
      } catch (_) {}
    }
  }

  void _autoResize() {
    final ta = _textarea;
    if (ta == null) return;
    ta.style.height = 'auto';
    final scrollHeight = ta.scrollHeight.toDouble();
    final minH = widget.minLines * _lineHeight + _verticalPadding;
    final maxH = widget.maxLines == null
        ? double.infinity
        : widget.maxLines! * _lineHeight + _verticalPadding;
    final finalHeight = scrollHeight.clamp(minH, maxH);
    ta.style.height = '${finalHeight}px';
    if (mounted && _measuredHeight != finalHeight) {
      setState(() => _measuredHeight = finalHeight);
    }
  }

  @override
  void didUpdateWidget(covariant NativeTextField old) {
    super.didUpdateWidget(old);
    final current = widget.controller.text;
    if (current != _lastKnownText) {
      _lastKnownText = current;
      final ta = _textarea;
      if (ta != null && ta.value != current) {
        ta.value = current;
        _autoResize();
      }
    }
    if (old.hintText != widget.hintText && _textarea != null) {
      _textarea!.placeholder = widget.hintText ?? '';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_syncDomFocus);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  double _computeHeight() {
    if (_measuredHeight != null) return _measuredHeight!;
    return widget.minLines * _lineHeight + _verticalPadding;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _computeHeight(),
      child: HtmlElementView(viewType: _viewId),
    );
  }
}