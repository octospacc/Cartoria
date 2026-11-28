import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/bookmarks.dart';
import '../../data/composer_draft.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../platform/clipboard_files.dart';
import '../../platform/clipboard_write.dart';
import '../../util/file_category.dart';
import '../../util/html_utils.dart';
import '../../util/mime.dart';
import '../../util/post_serialization.dart';
import '../../util/search_filter.dart';
import '../bookmark_import_helpers.dart';
import '../space_actions.dart';
import '../space_dialogs.dart';
import '../widgets/escape_back.dart';
import '../widgets/quill_bridge.dart';
import '../widgets/space_stats_dialog.dart';
import 'drive.dart';
import 'space_feed/attachment_picker.dart';
import 'space_feed/composer.dart';
import 'space_feed/composer_draft_controller.dart';
import 'space_feed/post_card.dart';

part 'space_feed/feed_actions.dart';
part 'space_feed/feed_app_bar.dart';
part 'space_feed/feed_compose.dart';
part 'space_feed/feed_import.dart';
part 'space_feed/feed_node.dart';
part 'space_feed/feed_paste.dart';
part 'space_feed/feed_scroll.dart';
part 'space_feed/feed_selection.dart';
part 'space_feed/feed_tree.dart';
part 'space_feed/feed_widgets.dart';

const int kPreviewReplyCount = 2;

class SpaceFeedScreen extends StatefulWidget {
  final VaultStore store;
  final Space space;
  final String? initialPostId;
  const SpaceFeedScreen({
    super.key,
    required this.store,
    required this.space,
    this.initialPostId,
  });

  @override
  State<SpaceFeedScreen> createState() => _SpaceFeedScreenState();
}

class _SpaceFeedScreenState extends State<SpaceFeedScreen> {
  Space get _space => widget.store.spaceById(widget.space.id) ?? widget.space;

  final _bodyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final FocusNode _composerFocusNode =
      FocusNode(debugLabel: 'feed-composer');
  final FocusNode _inlineQuillFocusNode =
      FocusNode(debugLabel: 'feed-inline-quill');
  bool _escHandledThisPress = false;
  quill.QuillController? _inlineQuillCtrl;
  String? _preservedBodyDelta;
  PostKind _kind = PostKind.note;
  final List<String> _pendingFileIds = [];
  DateTime? _postDateTime;
  final Set<String> _expanded = {};
  final Set<String> _collapsedReplies = {};
  final Set<String> _expandedQuotes = {};
  Map<String, List<Post>> _quotesByPost = {};
  bool _sending = false;
  bool _searchActive = false;
  bool _skipHooks = false;
  DateTimeRange? _searchDateRange;

  String? _highlightedPostId;
  Timer? _highlightTimer;

  late final ComposerDraftController _inlineDraftCtrl;
  bool _loadingInlineDraft = false;
  String _lastPlainText = '';

  final ItemScrollController _feedScroll = ItemScrollController();
  final ItemScrollController _searchScroll = ItemScrollController();

  int _scrollToken = 0;

  bool _selectionMode = false;
  final Set<String> _selectedPostIds = {};

  void _setStateSafe(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _inlineDraftCtrl = ComposerDraftController(
      store: widget.store,
      fieldKey: 'space:${widget.space.id}:inline',
    );
    _bodyCtrl.addListener(_onInlineFieldChanged);
    _urlCtrl.addListener(_onInlineFieldChanged);
    _inlineQuillCtrl = widget.store.richEditorEnabled
        ? quill.QuillController(
            document: quill.Document(),
            selection: const TextSelection.collapsed(offset: 0),
          )
        : null;
    _inlineQuillCtrl?.addListener(_onInlineFieldChanged);
    _loadInlineDraft();
    if (widget.initialPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToPost(widget.initialPostId!);
      });
    }
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyEsc);
    // HardwareKeyboard.instance.addHandler(_handleHardwareEsc);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyEsc);
    // HardwareKeyboard.instance.removeHandler(_handleHardwareEsc);
    _composerFocusNode.dispose();
    if (!_loadingInlineDraft) {
      _inlineDraftCtrl.saveNow(_buildInlineDraft());
    }
    _inlineDraftCtrl.dispose();
    _inlineQuillCtrl?.removeListener(_onInlineFieldChanged);
    _inlineQuillCtrl?.dispose();
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _resetQuillToEmpty() {
    if (_inlineQuillCtrl == null) return;
    _replaceInlineQuill(quill.QuillController(
      document: quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    ));
  }

  void _replaceInlineQuill(quill.QuillController next) {
    _inlineQuillCtrl?.removeListener(_onInlineFieldChanged);
    _inlineQuillCtrl?.dispose();
    _inlineQuillCtrl = next;
    _inlineQuillCtrl?.addListener(_onInlineFieldChanged);
  }

  @override
  Widget build(BuildContext context) {
    return EscapeBack(
        child: withClipboardPasteListener(
            onFiles: _onPastedFiles,
            child: AnimatedBuilder(
              animation: widget.store,
              builder: (context, _) {
                return Scaffold(
                  appBar: _buildAppBar(),
                  body: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: _buildContent(),
                          ),
                        ),
                      ),
                      if (!_searchActive && !_selectionMode)
                        Focus(
                            focusNode: _composerFocusNode,
                            canRequestFocus: false,
                            child: _withPasteShortcut(
                              _ComposerFooter(
                                child: InlineComposer(
                                  quillFocusNode: _inlineQuillFocusNode,
                                  kind: _kind,
                                  onKindChanged: (k) =>
                                      _updateInlineState(() => _kind = k),
                                  bodyCtrl: _bodyCtrl,
                                  quillCtrl: _inlineQuillCtrl,
                                  rich: widget.store.richEditorEnabled,
                                  urlCtrl: _urlCtrl,
                                  pendingFileIds: _pendingFileIds,
                                  store: widget.store,
                                  space: widget.space,
                                  onAttach: _attach,
                                  onSend: _sending ? null : _send,
                                  onRemoveFile: (id) => _updateInlineState(
                                      () => _pendingFileIds.remove(id)),
                                  postDateTime: _postDateTime,
                                  onPostDateTimeChanged: (v) =>
                                      _updateInlineState(
                                          () => _postDateTime = v),
                                  skipHooks: _skipHooks,
                                  onSkipHooksChanged: (v) =>
                                      _updateInlineState(() => _skipHooks = v),
                                  onReset: _resetInlineComposer,
                                  warnDraftLoss:
                                      !widget.store.richEditorEnabled &&
                                          _preservedBodyDelta != null,
                                ),
                              ),
                            ))
                    ],
                  ),
                );
              },
            )));
  }

  /// True if focus is anywhere inside the inline composer.
  ///
  /// Three checks, from cheapest/most reliable to more thorough:
  ///  1. `hasFocus` on the composer's own `FocusNode` (returns true for
  ///     ancestor nodes when any descendant holds primary focus).
  ///  2. `primaryFocus.ancestors` — walks the FocusNode tree, catches
  ///     cases where an intermediate Focus obscures `.hasFocus`.
  ///  3. `visitAncestorElements` — walks the widget (element) tree,
  ///     which is stable even when FocusNode parentage is broken by
  ///     Quill's internal Focus/FocusScope layer.
  bool _isComposerFocused() {
    if (_composerFocusNode.hasFocus) return true;

    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;

    for (final ancestor in primary.ancestors) {
      if (identical(ancestor, _composerFocusNode)) return true;
    }

    final ctx = primary.context;
    if (ctx != null) {
      var inside = false;
      ctx.visitAncestorElements((el) {
        if (el.widget is InlineComposer) {
          inside = true;
          return false;
        }
        return true;
      });
      if (inside) return true;
    }

    return false;
  }

  /// Unfocus the composer. Runs twice (immediate + next frame) because
  /// Quill re-requests focus in a post-frame callback after losing it
  /// while its selection is active — a single unfocus appears to do
  /// nothing.
  void _doUnfocusComposer() {
    _inlineQuillFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inlineQuillFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  /// Runs before the focus tree. Owns the entire ESC decision tree
  /// for the feed:
  ///
  ///   1. Composer focused → unfocus the composer, feed stays.
  ///   2. Selection mode active → exit selection mode.
  ///   3. Search mode active → close search.
  ///   4. Otherwise → pop the feed.
  ///
  /// Point 4 is what makes successive ESC presses work: after the
  /// first ESC unfocuses, primary focus moves to `Navigator Scope`
  /// (above EscapeBack's Focus node), so without this the second ESC
  /// would be swallowed by nothing and vanish.
  KeyEventResult _handleEarlyEsc(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (!mounted) return KeyEventResult.ignored;

    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return KeyEventResult.ignored;

    if (_isComposerFocused()) {
      _doUnfocusComposer();
      return KeyEventResult.handled;
    }
    if (_selectionMode) {
      _exitSelectionMode();
      return KeyEventResult.handled;
    }
    if (_searchActive) {
      _setStateSafe(() {
        _searchCtrl.clear();
        _searchActive = false;
        _searchDateRange = null;
      });
      return KeyEventResult.handled;
    }

    Navigator.of(context).maybePop();
    return KeyEventResult.handled;
  }
}
