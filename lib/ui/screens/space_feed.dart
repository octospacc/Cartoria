library space_feed;

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
import '../../util/post_serialization.dart';
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
  const SpaceFeedScreen({super.key, required this.store, required this.space});

  @override
  State<SpaceFeedScreen> createState() => _SpaceFeedScreenState();
}

class _SpaceFeedScreenState extends State<SpaceFeedScreen> {
  Space get _space => widget.store.spaceById(widget.space.id) ?? widget.space;

  final _bodyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
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

  /// The plaintext value last written into `_bodyCtrl` by the app (on
  /// draft load, reset, or after send). Used to distinguish a real
  /// content edit from a cursor/selection change, so focusing the plain
  /// field doesn't destroy a preserved rich delta.
  String _lastPlainText = '';

  String? _highlightedPostId;
  Timer? _highlightTimer;

  late final ComposerDraftController _inlineDraftCtrl;
  bool _loadingInlineDraft = false;

  final ItemScrollController _feedScroll = ItemScrollController();
  final ItemScrollController _searchScroll = ItemScrollController();

  final Map<String, GlobalKey> _postKeys = {};
  int _scrollToken = 0;

  bool _selectionMode = false;
  final Set<String> _selectedPostIds = {};

  void _setStateSafe(VoidCallback fn) => setState(fn);

  GlobalKey _keyFor(String postId) =>
      _postKeys.putIfAbsent(postId, () => GlobalKey());

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
  }

  @override
  void dispose() {
    if (!_loadingInlineDraft) {
      _inlineDraftCtrl.saveNow(_buildInlineDraft());
    }
    _inlineDraftCtrl.dispose();
    _inlineQuillCtrl?.removeListener(_onInlineFieldChanged);
    _inlineQuillCtrl?.dispose();
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    _postKeys.clear();
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
        onEscape: _selectionMode || _searchActive
            ? () {
                if (_selectionMode) {
                  _exitSelectionMode();
                } else {
                  _setStateSafe(() {
                    _searchCtrl.clear();
                    _searchActive = false;
                  });
                }
              }
            : null,
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
                        _withPasteShortcut(
                          _ComposerFooter(
                            child: InlineComposer(
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
                                  _updateInlineState(() => _postDateTime = v),
                              skipHooks: _skipHooks,
                              onSkipHooksChanged: (v) =>
                                  _updateInlineState(() => _skipHooks = v),
                              onReset: _resetInlineComposer,
                              warnDraftLoss: !widget.store.richEditorEnabled &&
                                  _preservedBodyDelta != null,
                            ),
                          ),
                        )
                    ],
                  ),
                );
              },
            )));
  }
}