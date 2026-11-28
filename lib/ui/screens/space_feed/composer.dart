library composer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';

import '../../../data/composer_draft.dart';
import '../../../data/models.dart';
import '../../../data/store.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/clipboard_files.dart';
import '../../../util/html_utils.dart';
import '../../widgets/emoji_picker_sheet.dart';
import '../../widgets/quill_bridge.dart';
import '../../widgets/rich_text_editor.dart';
import '../../widgets/spell_check.dart';
import '../drive/file_viewer.dart';
import '../full_screen_plain_text_editor.dart';
import '../full_screen_text_editor.dart';
import 'attachment_picker.dart';
import 'composer_draft_controller.dart';

part 'composer_datetime.dart';
part 'composer_sheet.dart';

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
  final String? bodyHtml;
  final String? url;
  final String? title;
  final String? description;
  final String? thumbnail;
  final List<String> fileIds;
  final DateTime? createdAt;
  final String? quotedPostId;
  final bool skipHooks;
  final String draftFieldKey;
  final String? targetSpaceId;

  const ComposerResult({
    required this.kind,
    required this.body,
    this.bodyHtml,
    required this.url,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.fileIds,
    this.createdAt,
    this.quotedPostId,
    this.skipHooks = false,
    required this.draftFieldKey,
    this.targetSpaceId,
  });
}

// ── Inline composer ───────────────────────────────────────────────────────

class InlineComposer extends StatelessWidget {
  final PostKind kind;
  final ValueChanged<PostKind> onKindChanged;
  final TextEditingController bodyCtrl;
  final quill.QuillController? quillCtrl;
  final FocusNode? quillFocusNode;
  final bool rich;
  final TextEditingController urlCtrl;
  final List<String> pendingFileIds;
  final VaultStore store;
  final Space space;
  final VoidCallback onAttach;
  final VoidCallback? onSend;
  final ValueChanged<String> onRemoveFile;
  final DateTime? postDateTime;
  final ValueChanged<DateTime?> onPostDateTimeChanged;
  final bool skipHooks;
  final ValueChanged<bool> onSkipHooksChanged;
  final VoidCallback onReset;
  final bool warnDraftLoss;

  const InlineComposer({
    super.key,
    required this.kind,
    required this.onKindChanged,
    required this.bodyCtrl,
    this.quillCtrl,
    this.quillFocusNode,
    this.rich = false,
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
    this.warnDraftLoss = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (warnDraftLoss) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.composerRichFormattingLossWarning,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (pendingFileIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pendingFileIds.map((id) {
                final f = store.fileById(space.id, id);
                return InputChip(
                  label: Text(f?.name ?? id, overflow: TextOverflow.ellipsis),
                  onDeleted: () => onRemoveFile(id),
                  onPressed:
                      f == null ? null : () => _openFileViewer(context, f),
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
        if (rich && quillCtrl != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RichTextEditor(
              controller: quillCtrl!,
              focusNode: quillFocusNode,
              hintText: kind == PostKind.note
                  ? l.composerBodyHintNote
                  : l.composerBodyHintBookmark,
              minHeight: 40,
              maxHeight: 180,
            ),
          )
        else
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
              onPressed: () => _openEmoji(context),
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
              onPressed: () => _openFullScreenEditor(context),
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

  Future<void> _openEmoji(BuildContext context) async {
    if (rich && quillCtrl != null) {
      final emoji = await pickEmoji(context);
      if (emoji == null) return;
      final sel = quillCtrl!.selection;
      final index = sel.isValid ? sel.start : quillCtrl!.document.length - 1;
      quillCtrl!.document.insert(index, emoji);
      quillCtrl!.updateSelection(
        TextSelection.collapsed(offset: index + emoji.length),
        quill.ChangeSource.local,
      );
    } else {
      await showEmojiPickerSheet(context, bodyCtrl);
    }
  }

  Future<void> _openFullScreenEditor(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    final isNote = kind == PostKind.note;
    if (rich && quillCtrl != null) {
      await FullScreenTextEditor.show(
        context,
        controller: quillCtrl!,
        title: isNote
            ? l.composerFullScreenNoteTitle
            : l.composerFullScreenBookmarkTitle,
        hintText: isNote
            ? l.composerFullScreenNoteHint
            : l.composerFullScreenBookmarkHint,
      );
    } else {
      await FullScreenPlainTextEditor.show(
        context,
        controller: bodyCtrl,
        title: isNote
            ? l.composerFullScreenNoteTitle
            : l.composerFullScreenBookmarkTitle,
        hintText: isNote
            ? l.composerFullScreenNoteHint
            : l.composerFullScreenBookmarkHint,
      );
    }
  }

  Widget _buildResetButton(BuildContext context) {
    final listenables = <Listenable>[bodyCtrl, urlCtrl];
    if (rich && quillCtrl != null) listenables.add(quillCtrl!);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (_, __) {
        final hasContent =
            (rich && quillCtrl != null
                ? quillToPlaintext(quillCtrl!).isNotEmpty
                : bodyCtrl.text.isNotEmpty) ||
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
    if (!context.mounted) return;
    for (final id in List.of(pendingFileIds)) {
      if (store.fileById(space.id, id) == null) {
        onRemoveFile(id);
      }
    }
  }
}