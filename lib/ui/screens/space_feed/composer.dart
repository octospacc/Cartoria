library composer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../platform/clipboard_files.dart';
import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../util/html_utils.dart';
import '../../widgets/spell_check.dart';
import '../../widgets/emoji_picker_sheet.dart';
import '../../screens/full_screen_text_editor.dart';
import '../../../data/composer_draft.dart';
import '../../../l10n/l10n.dart';
import '../drive/file_viewer.dart';
import 'composer_draft_controller.dart';
import 'attachment_picker.dart';

part 'composer_sheet.dart';
part 'composer_datetime.dart';

// ── Shared: date/time picker + formatter ──────────────────────────────────

Future<DateTime?> _pickPostDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final base = initial ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    helpText: context.l10n.composerPostedAt,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
    helpText: context.l10n.composerPostedAt,
  );
  if (time == null || !context.mounted) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a post's timestamp in the current UI locale.
///
/// Month names and 24-hour time come from `intl`'s locale data, which
/// `flutter_localizations` initializes at app startup for every locale
/// in `MaterialApp.supportedLocales`. Same-year timestamps omit the
/// year to keep the chip compact; different-year timestamps include it.
String _formatPostDateTime(BuildContext context, DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final locale = Localizations.localeOf(context).toLanguageTag();
  final dateFmt = local.year == now.year
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  final timeFmt = DateFormat.Hm(locale);
  return '${dateFmt.format(local)}, ${timeFmt.format(local)}';
}

// ── Compose result ────────────────────────────────────────────────────────

class ComposerResult {
  final PostKind kind;
  final String body;
  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> fileIds;

  /// Only meaningful for new posts (reply or top-level). Null means
  /// "use now at send time"; ignored for edits.
  final DateTime? createdAt;

  /// The post being quoted, if this composition is a quote. Null for
  /// ordinary new posts and for replies. Ignored on edit — the existing
  /// post's quote reference is preserved by `updatePost` regardless.
  final String? quotedPostId;

  /// When true, hooks are not fired for this save. Only meaningful for
  /// create and edit actions; ignored when composing a reply or quote
  /// that reuses the previous value (currently always false for both).
  final bool skipHooks;

  /// Field key used by the sheet's draft controller. Parents clear the
  /// draft via `store.deleteComposerDraft(result.draftFieldKey)` after
  /// the post is successfully persisted — this preserves the draft if
  /// post creation fails.
  final String draftFieldKey;

  const ComposerResult({
    required this.kind,
    required this.body,
    required this.url,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.fileIds,
    this.createdAt,
    this.quotedPostId,
    this.skipHooks = false,
    required this.draftFieldKey,
  });
}

// ── Inline composer ───────────────────────────────────────────────────────

class InlineComposer extends StatelessWidget {
  final PostKind kind;
  final ValueChanged<PostKind> onKindChanged;
  final TextEditingController bodyCtrl;
  final TextEditingController urlCtrl;
  final List<String> pendingFileIds;
  final VaultStore store;
  final Space space;
  final VoidCallback onAttach;
  final VoidCallback? onSend;
  final ValueChanged<String> onRemoveFile;

  /// Post datetime override. Null = "now at send time".
  final DateTime? postDateTime;
  final ValueChanged<DateTime?> onPostDateTimeChanged;

  final bool skipHooks;
  final ValueChanged<bool> onSkipHooksChanged;

  final VoidCallback onReset;

  const InlineComposer({
    super.key,
    required this.kind,
    required this.onKindChanged,
    required this.bodyCtrl,
    required this.urlCtrl,
    required this.pendingFileIds,
    required this.store,
    required this.space,
    required this.onAttach,
    required this.onSend,
    required this.onRemoveFile,
    this.postDateTime,
    required this.onPostDateTimeChanged,
    this.skipHooks = false,
    required this.onSkipHooksChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingFileIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pendingFileIds.map((id) {
                final f = store.fileById(space.id, id);
                return InputChip(
                  label: Text(f?.name ?? id,
                      overflow: TextOverflow.ellipsis),
                  onDeleted: () => onRemoveFile(id),
                  onPressed: f == null
                      ? null
                      : () => _openFileViewer(context, f),
                );
              }).toList(),
            ),
          ),
        if (kind == PostKind.bookmark)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                isDense: true,
                hintText: l.composerUrlHint,
                prefixIcon: const Icon(Icons.link, size: 18),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        TextField(
          controller: bodyCtrl,
          minLines: 1,
          maxLines: 6,
          spellCheckConfiguration: kSpellCheckConfig,
          contextMenuBuilder: spellCheckContextMenuBuilder,
          decoration: InputDecoration(
            isDense: true,
            hintText: kind == PostKind.note
                ? l.composerBodyHintNote
                : l.composerBodyHintBookmark,
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 2),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;

            final modeSelector = SegmentedButton<PostKind>(
              segments: [
                ButtonSegment(
                    value: PostKind.note,
                    icon: const Icon(Icons.notes, size: 16),
                    label: Text(l.composerNote)),
                ButtonSegment(
                    value: PostKind.bookmark,
                    icon: const Icon(Icons.bookmark_outline, size: 16),
                    label: Text(l.composerLink)),
              ],
              selected: {kind},
              onSelectionChanged: (s) => onKindChanged(s.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );

            final emojiButton = IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined, size: 20),
              tooltip: l.composerEmojiTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: () => showEmojiPickerSheet(context, bodyCtrl),
            );

            final hooksButton = IconButton(
              icon: Icon(skipHooks ? Icons.flash_off : Icons.flash_on,
                  size: 20),
              tooltip:
                  skipHooks ? l.composerHooksSkip : l.composerHooksRun,
              color: skipHooks
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.primary,
              visualDensity: VisualDensity.compact,
              onPressed: () => onSkipHooksChanged(!skipHooks),
            );

            final fullscreenButton = IconButton(
              icon: const Icon(Icons.open_in_full, size: 20),
              tooltip: l.composerExpand,
              visualDensity: VisualDensity.compact,
              onPressed: () => _openFullScreenEditor(context, bodyCtrl),
            );

            final attachButton = IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: l.composerAttach,
              visualDensity: VisualDensity.compact,
              onPressed: onAttach,
            );

            final sendButton = IconButton.filled(
              icon: const Icon(Icons.send, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: onSend,
            );

            if (!narrow) {
              return Row(
                children: [
                  modeSelector,
                  const Spacer(),
                  hooksButton,
                  emojiButton,
                  _DateTimeChip(
                    value: postDateTime,
                    onChanged: onPostDateTimeChanged,
                  ),
                  fullscreenButton,
                  attachButton,
                  _buildResetButton(context),
                  sendButton,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    modeSelector,
                    const Spacer(),
                    hooksButton,
                    emojiButton,
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _DateTimeChip(
                      value: postDateTime,
                      onChanged: onPostDateTimeChanged,
                    ),
                    fullscreenButton,
                    attachButton,
                    _buildResetButton(context),
                    const Spacer(),
                    sendButton,
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openFullScreenEditor(
    BuildContext context,
    TextEditingController ctrl,
  ) async {
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    final isNote = kind == PostKind.note;
    await FullScreenTextEditor.show(
      context,
      controller: ctrl,
      title: isNote
          ? l.composerFullScreenNoteTitle
          : l.composerFullScreenBookmarkTitle,
      hintText: isNote
          ? l.composerFullScreenNoteHint
          : l.composerFullScreenBookmarkHint,
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: bodyCtrl,
      builder: (_, __, ___) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: urlCtrl,
        builder: (_, __, ___) {
          // Matches `ComposerDraft.isEmpty` — reset is enabled only when
          // there's something worth discarding.
          final hasContent = bodyCtrl.text.isNotEmpty ||
              urlCtrl.text.isNotEmpty ||
              pendingFileIds.isNotEmpty ||
              postDateTime != null ||
              skipHooks ||
              kind != PostKind.note;
              return IconButton(
                icon: const Icon(Icons.restart_alt, size: 20),
                tooltip: hasContent ? context.l10n.composerDiscardDraft : null,
                visualDensity: VisualDensity.compact,
                onPressed: hasContent ? onReset : null,
              );
        },
      ),
    );
  }

  Future<void> _openFileViewer(BuildContext context, DriveFile f) async {
    final siblings = <DriveFile>[];
    for (final id in pendingFileIds) {
      final df = store.fileById(space.id, id);
      if (df != null) siblings.add(df);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FileViewerScreen(
          store: store,
          space: space,
          file: f,
          allowDelete: true,
          siblings: siblings,
        ),
      ),
    );
    // Any of the pending files may have been deleted while the viewer
    // was open (not just the initially-tapped one). Sweep them all so
    // no chip lingers on a nonexistent file.
    for (final id in List.of(pendingFileIds)) {
      if (store.fileById(space.id, id) == null) {
        onRemoveFile(id);
      }
    }
  }
}
