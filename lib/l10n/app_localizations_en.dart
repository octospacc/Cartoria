// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cartoria';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonImport => 'Import';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonReset => 'Reset';

  @override
  String get onboardingWelcome => 'Welcome';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingCreateFirstSpace => 'Create your first space';

  @override
  String get onboardingBody =>
      'A space holds its own notes, bookmarks, and files. Spaces are independent — you can add more later.';

  @override
  String get onboardingSpaceName => 'Space name';

  @override
  String get onboardingCreateSpace => 'Create space';

  @override
  String get spacesTitle => 'Spaces';

  @override
  String get spacesHooksTooltip => 'Hooks';

  @override
  String get spacesSyncTooltip => 'Sync';

  @override
  String get spacesImportTooltip => 'New space from file…';

  @override
  String get spacesSettingsTooltip => 'Settings';

  @override
  String get spacesEmpty => 'No spaces yet';

  @override
  String get spacesEmptyHint =>
      'Tap + to create your first space, or import from a file using the icon at the top.';

  @override
  String get spacesEmptyLabel => 'Empty';

  @override
  String get spacesStatistics => 'Statistics';

  @override
  String get spacesEdit => 'Edit space…';

  @override
  String get spacesExport => 'Export space…';

  @override
  String get spacesDelete => 'Delete space…';

  @override
  String spacesDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get spacesDeleteBody =>
      'This removes every post and file in this space. Cannot be undone.';

  @override
  String spacesCountNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String spacesCountBookmarks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookmarks',
      one: '1 bookmark',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String spacesCountReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String spacesCountFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get spaceDialogNewTitle => 'New space';

  @override
  String get spaceDialogEditTitle => 'Edit space';

  @override
  String get spaceDialogNameLabel => 'Name';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageSection => 'LANGUAGE';

  @override
  String get settingsLanguageDescription =>
      'Language used by the app interface. Also used for spell check in the composer.';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageItalian => 'Italiano';

  @override
  String get settingsBackupsSection => 'BACKUPS';

  @override
  String get settingsBackupsDescription =>
      'A backup of the vault is created before each pull, so a bad pull cannot destroy unpushed local changes. Old backups are deleted automatically beyond the retention limit.';

  @override
  String get settingsRetentionLabel => 'Retention (number of backups)';

  @override
  String get settingsRetentionHelper =>
      'Leave empty to use the default. Set to 0 to disable pre-pull backups entirely.';

  @override
  String get settingsRetentionSaveTooltip => 'Save';

  @override
  String settingsRetentionCurrent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Currently keeping up to $count backups',
      one: 'Currently keeping up to 1 backup',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupsLoading => 'Loading backups…';

  @override
  String settingsBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count backups',
      one: '1 backup',
      zero: 'No backups',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupsEmpty =>
      'No backups yet. Backups are created automatically before each pull.';

  @override
  String get settingsBackupsClearAll => 'Clear all';

  @override
  String get settingsBackupsExportTooltip => 'Export';

  @override
  String get settingsBackupsDeleteTooltip => 'Delete';

  @override
  String settingsBackupsClearTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Clear $count backups?',
      one: 'Clear 1 backup?',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupsClearBody =>
      'Deletes every pre-pull backup. Current vault data is not affected. This cannot be undone.';

  @override
  String settingsBackupDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get settingsBackupDeleteBody =>
      'Deletes this backup. Other backups and current vault data are not affected.';

  @override
  String settingsRetentionSaved(int count) {
    return 'Retention set to $count';
  }

  @override
  String get settingsRetentionReset => 'Retention reset to default';

  @override
  String get settingsRetentionDisabled => 'Pre-pull backups disabled';

  @override
  String get settingsRetentionInvalid =>
      'Retention must be a non-negative integer';

  @override
  String settingsSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String settingsListBackupsFailed(String error) {
    return 'Could not list backups: $error';
  }

  @override
  String settingsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String settingsDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get spaceImportUnsupported => 'Unsupported file type';

  @override
  String get spaceImportSinglePost =>
      'Single-post file — open a space and use Import… there';

  @override
  String get spaceImportNoBookmarks => 'No bookmarks found';

  @override
  String get spaceImportDetails => 'Details';

  @override
  String get spaceImportNothing => 'Nothing imported';

  @override
  String spaceImportSummary(int ok, int failed, int cancelled) {
    return '$ok imported, $failed failed, $cancelled cancelled';
  }

  @override
  String spaceImportSummaryOkFailed(int ok, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      ok,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$ok file$_temp0 imported · $failed failed';
  }

  @override
  String spaceImportSummaryOk(int ok) {
    String _temp0 = intl.Intl.pluralLogic(
      ok,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$ok file$_temp0 imported';
  }

  @override
  String spaceImportSummaryFailed(int failed) {
    return '$failed failed';
  }

  @override
  String spaceImportSummaryCancelled(int cancelled) {
    return '$cancelled cancelled';
  }

  @override
  String spaceImportZipResult(String name) {
    return 'Imported \"$name\"';
  }

  @override
  String spaceImportBookmarksResult(int count, String name) {
    return 'Imported $count into \"$name\"';
  }

  @override
  String get spaceImportBookmarksDialogTitle => 'Import bookmarks';

  @override
  String get spaceImportDefaultBookmarksName => 'Imported Bookmarks';

  @override
  String get feedSearchHint => 'Search this space…';

  @override
  String get feedSearchClear => 'Clear';

  @override
  String get feedSearchClose => 'Close search';

  @override
  String feedSearchNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String feedSearchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String get feedEmpty => 'Nothing here yet. Write a note or save a link.';

  @override
  String get feedSelect => 'Select';

  @override
  String get feedDrive => 'Drive';

  @override
  String get feedExitSelection => 'Exit selection';

  @override
  String feedSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get feedSelectPosts => 'Select posts';

  @override
  String get feedDeleteSelected => 'Delete selected';

  @override
  String feedDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count posts?',
      one: 'Delete 1 post?',
    );
    return '$_temp0';
  }

  @override
  String get feedDeleteSelectedBody => 'This cannot be undone.';

  @override
  String feedDeleteSelectedOrphaned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies will become top-level.',
      one: '1 reply will become top-level.',
    );
    return '$_temp0';
  }

  @override
  String get feedMenuImport => 'Import…';

  @override
  String get feedMenuImportSource => 'Paste post source…';

  @override
  String feedImportOneFile(String name) {
    return 'Imported \"$name\"';
  }

  @override
  String get feedImportPost => 'Post imported';

  @override
  String get feedImportBookmarksFound => 'No bookmarks found in file';

  @override
  String feedImportFilesSummary(int ok) {
    return '$ok imported';
  }

  @override
  String feedImportErrorsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String get feedUnsupportedFile => 'Unsupported file type';

  @override
  String get feedPasteDialogTitle => 'Paste post source';

  @override
  String get feedPasteDialogHint =>
      'Paste a Cartoria post file — the same format as entries/<id>.html: a <!--- … ---> JSON frontmatter block followed by the HTML body. A fresh ID is generated if none is present.';

  @override
  String get composerNote => 'Note';

  @override
  String get composerLink => 'Link';

  @override
  String get composerBodyHintNote => 'Write something…';

  @override
  String get composerBodyHintBookmark => 'Why save this?';

  @override
  String get composerUrlHint => 'https://…';

  @override
  String get composerEmojiTooltip => 'Emoji';

  @override
  String get composerHooksSkip => 'Hooks skipped this save — tap to re-enable';

  @override
  String get composerHooksRun => 'Hooks will run on save — tap to skip';

  @override
  String get composerExpand => 'Expand to full screen';

  @override
  String get composerAttach => 'Attach';

  @override
  String get composerSend => 'Send';

  @override
  String get composerDiscardDraft => 'Discard draft';

  @override
  String get composerSetDateTime => 'Set post date/time';

  @override
  String get composerNewPost => 'New post';

  @override
  String get composerReply => 'Reply';

  @override
  String get composerQuote => 'Quote';

  @override
  String get composerPost => 'Post';

  @override
  String get composerEditing => 'Edit post';

  @override
  String get composerQuoting => 'Quote';

  @override
  String composerReplyingTo(String preview) {
    return 'Replying to: $preview';
  }

  @override
  String composerQuotingPreview(String preview) {
    return 'Quoting: $preview';
  }

  @override
  String get composerUrlLabel => 'URL';

  @override
  String get composerRefreshMetadata => 'Refresh metadata';

  @override
  String get composerTitleLabel => 'Title';

  @override
  String get composerDescriptionLabel => 'Description';

  @override
  String get composerBodyLabel => 'Body';

  @override
  String get composerBodyHint => 'Write the body…';

  @override
  String get composerPostedAt => 'Posted at';

  @override
  String get composerPostedNow => 'Now (default)';

  @override
  String get composerSetTime => 'Set…';

  @override
  String get composerChangeTime => 'Change';

  @override
  String get composerResetTime => 'Reset to now';

  @override
  String get composerHooksRunOnSave => 'Run hooks on save';

  @override
  String get composerHooksWillSkip =>
      'Hooks will be skipped. You can trigger them later from the post menu.';

  @override
  String composerHooksWillRun(String action) {
    return 'Matching hooks will fire when you tap $action.';
  }

  @override
  String get composerAddFile => 'Add file';

  @override
  String get composerUnsavedDraft => 'Unsaved draft';

  @override
  String composerUnsavedDraftFrom(String when) {
    return 'Unsaved draft from $when';
  }

  @override
  String get composerDraftReset => 'Reset';

  @override
  String get composerMetadataFetchFailed => 'Could not fetch metadata';

  @override
  String get composerUrlRequired => 'Enter a URL first';

  @override
  String get composerBookmarkNeedsUrl => 'A bookmark needs a URL';

  @override
  String get composerEscapeBack => 'Close';

  @override
  String get composerRelativeJustNow => 'just now';

  @override
  String composerRelativeMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String composerRelativeHours(int count) {
    return '${count}h ago';
  }

  @override
  String composerRelativeDays(int count) {
    return '${count}d ago';
  }

  @override
  String get composerFullScreenNoteTitle => 'Note';

  @override
  String get composerFullScreenNoteHint => 'Write something…';

  @override
  String get composerFullScreenBookmarkTitle => 'Why save this';

  @override
  String get composerFullScreenBookmarkHint => 'Why save this?';

  @override
  String get composerFullScreenEditTitle => 'Edit post body';

  @override
  String get composerFullScreenReplyTitle => 'Reply body';

  @override
  String get composerFullScreenQuoteTitle => 'Quote body';

  @override
  String get composerFullScreenNewTitle => 'Post body';

  @override
  String get attachmentUpload => 'Upload new files';

  @override
  String get attachmentPaste => 'Paste from clipboard';

  @override
  String get attachmentRecall => 'Recall from drive';

  @override
  String get attachmentPasteEmpty =>
      'No image or file found in clipboard. On web, try pressing Ctrl+V in the composer instead.';

  @override
  String attachmentPasteFailed(String error) {
    return 'Paste failed: $error';
  }

  @override
  String attachmentUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String attachmentUploadFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count file$_temp0 failed to upload';
  }

  @override
  String get attachmentDriveEmpty => 'Drive is empty';

  @override
  String get postReply => 'Reply';

  @override
  String get postQuote => 'Quote';

  @override
  String get postEdit => 'Edit';

  @override
  String get postSource => 'Show source…';

  @override
  String get postHookStatus => 'Hook status…';

  @override
  String get postDelete => 'Delete';

  @override
  String postShowMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'replies',
      one: 'reply',
    );
    return 'Show $count more $_temp0';
  }

  @override
  String postHideReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'replies',
      one: 'reply',
    );
    return 'Hide $count $_temp0';
  }

  @override
  String get postShowFewer => 'Show fewer';

  @override
  String postRepliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'replies',
      one: 'reply',
    );
    return '$count $_temp0';
  }

  @override
  String get postDeleteNote => 'Delete this note?';

  @override
  String get postDeleteBookmark => 'Delete this bookmark?';

  @override
  String get postDeleteBody =>
      'Attached files stay in the drive. Replies will become top-level. Cannot be undone.';

  @override
  String get postQuotedUnavailable => 'Quoted post unavailable';

  @override
  String get postQuotedFromSpace => 'Quoted from this space';

  @override
  String get postQuotedIncludesAnother => '↪ includes another quote';

  @override
  String get postQuotedExternal => 'External quote';

  @override
  String get postQuotedOpenHint => 'Tap to view the quoted post';

  @override
  String get postHookRunning => 'Hooks running…';

  @override
  String get postHookSuccess => 'Hooks succeeded';

  @override
  String get postHookFailed => 'Hooks failed — tap for details';

  @override
  String postEdited(String when) {
    return '· edited $when';
  }

  @override
  String postShowQuotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quotes',
      one: '1 quote',
    );
    return '$_temp0';
  }

  @override
  String postHideQuotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quotes',
      one: '1 quote',
    );
    return 'Hide $_temp0';
  }

  @override
  String get postQuotedByHeader => 'QUOTED BY';

  @override
  String get startupErrorTitle => 'Startup error';

  @override
  String get startupErrorBody =>
      'Cartoria could not finish starting up. This is usually a permissions or disk issue, not a bug in the app.';

  @override
  String get startupErrorStack => 'Stack:';

  @override
  String get driveTitle => 'Drive';

  @override
  String get driveMoreTooltip => 'More';

  @override
  String get driveOpen => 'Open';

  @override
  String get driveUsageAction => 'Show posts using this file…';

  @override
  String get driveShareAction => 'Share / download';

  @override
  String get driveDeleteAction => 'Delete';

  @override
  String get driveSelectFiles => 'Select files';

  @override
  String driveSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get driveExitSelection => 'Exit selection';

  @override
  String get driveSelectUnused => 'Select unused';

  @override
  String get driveDeleteSelected => 'Delete selected';

  @override
  String get driveSearchTooltip => 'Search';

  @override
  String get driveSearchClose => 'Close search';

  @override
  String get driveSearchHint => 'Search files…';

  @override
  String get driveClear => 'Clear';

  @override
  String get driveGridTooltip => 'Grid view';

  @override
  String get driveListTooltip => 'List view';

  @override
  String get driveEmptyState =>
      'No files yet.\nUpload one here, or attach from a post.';

  @override
  String driveNoMatch(String query) {
    return 'No files match \"$query\".';
  }

  @override
  String driveSummaryTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String driveSummaryOffloaded(int count) {
    return '$count offloaded';
  }

  @override
  String driveSummaryUnused(int count) {
    return '$count unused';
  }

  @override
  String get driveUsageUsed => 'used';

  @override
  String get driveUsageUnused => 'unused';

  @override
  String get driveStatusMissing => 'missing';

  @override
  String get driveStatusRemote => 'remote';

  @override
  String driveDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Delete $_temp0?';
  }

  @override
  String get driveDeleteSelectedBody =>
      'Posts that reference these files will lose the attachments. This cannot be undone.';

  @override
  String driveDeleteFileTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get driveDeleteFileBody =>
      'Posts that reference this file will lose the attachment.';

  @override
  String driveMissingTitle(String name) {
    return '\"$name\" is missing';
  }

  @override
  String get driveMissingBody =>
      'This file is referenced by one or more posts, but its content isn\'t stored anywhere on this device or the sync remote.\n\nYou can restore it by re-importing the full export it came from, pulling from the sync remote if it still has the file, or by picking a replacement file from this device.';

  @override
  String get driveUploadReplacement => 'Upload replacement…';

  @override
  String driveRestored(String name) {
    return 'Restored \"$name\"';
  }

  @override
  String driveRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String driveUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String driveUploadSummaryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files uploaded',
      one: '1 file uploaded',
    );
    return '$_temp0';
  }

  @override
  String driveUploadSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files failed',
      one: '1 file failed',
    );
    return '$_temp0';
  }

  @override
  String get driveUploadNothing => 'No files uploaded';

  @override
  String driveUploadDialogTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files failed to upload',
      one: '1 file failed to upload',
    );
    return '$_temp0';
  }

  @override
  String drivePastedFromClipboard(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'Added $_temp0 from clipboard.';
  }

  @override
  String get drivePasteEmpty =>
      'No image or file found in clipboard. On web, try pasting into a composer.';

  @override
  String drivePasteFailed(String error) {
    return 'Paste failed: $error';
  }

  @override
  String get driveDownloadTitle => 'Download from remote?';

  @override
  String driveDownloadBody(String name) {
    return '\"$name\" is not on this device. Fetch it now?';
  }

  @override
  String get driveDownloadConfirm => 'Download';

  @override
  String driveDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String linkPreviewOpenFailed(String url) {
    return 'Could not open $url';
  }

  @override
  String linkPreviewOpenError(String error) {
    return 'Could not open link: $error';
  }

  @override
  String get postBodyImagePlaceholder => '[image]';

  @override
  String postBodyImagePlaceholderAlt(String alt) {
    return '[image: $alt]';
  }

  @override
  String get postBodyImageFailed => 'Image failed to load';

  @override
  String postBodyOpenFailed(String url) {
    return 'Could not open $url';
  }

  @override
  String postBodyOpenError(String error) {
    return 'Could not open link: $error';
  }

  @override
  String get emojiTitle => 'Emoji';

  @override
  String get emojiCloseTooltip => 'Close';

  @override
  String get fileUsageEmptyTitle => 'Not referenced by any post';

  @override
  String fileUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts reference this file',
      one: '1 post references this file',
    );
    return '$_temp0';
  }

  @override
  String get fileUsageNoPosts => 'No posts reference this file.';

  @override
  String get fileUsageNoText => '(no text)';

  @override
  String postSourceTitle(String shortId) {
    return 'Source · $shortId…';
  }

  @override
  String get postSourceCopied => 'Source copied';

  @override
  String get postSourceCopy => 'Copy';

  @override
  String postSourceReadFailed(String error) {
    return 'Could not read source: $error';
  }

  @override
  String spaceActionsExportTitle(String name) {
    return 'Export \"$name\"';
  }

  @override
  String get spaceActionsFull => 'Full';

  @override
  String spaceActionsFullBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count and downloaded',
      one: '1 and downloaded',
      zero: 'none',
    );
    return 'Includes every file. Offloaded files are $_temp0 from the sync remote before the zip is built. Slowest, but the export is self-contained.';
  }

  @override
  String get spaceActionsOnDisk => 'On-disk only';

  @override
  String spaceActionsOnDiskBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offloaded files skipped.',
      one: '1 offloaded file skipped.',
      zero: 'No files are offloaded.',
    );
    return 'Includes files currently stored on this device. $_temp0 File references are preserved in the export; re-importing the full zip (or syncing) later can restore the missing blobs.';
  }

  @override
  String get spaceActionsNoMedia => 'Without media';

  @override
  String get spaceActionsNoMediaBody =>
      'No files at all. Only the text (notes, bookmarks) and file references. Smallest export; every file will appear as missing on import until restored.';

  @override
  String spaceActionsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String spaceStatsCouldNotCompute(String error) {
    return 'Could not compute stats: $error';
  }

  @override
  String get spaceStatsContent => 'Content';

  @override
  String get spaceStatsTotal => 'Total';

  @override
  String get spaceStatsNotes => 'Notes';

  @override
  String get spaceStatsBookmarks => 'Bookmarks';

  @override
  String get spaceStatsReplies => 'Replies (nested)';

  @override
  String get spaceStatsDrive => 'Drive';

  @override
  String get spaceStatsFiles => 'Files';

  @override
  String get spaceStatsStorage => 'Storage';

  @override
  String get spaceStatsSpaceSize => 'Space size';

  @override
  String get spaceStatsLocation => 'Location';

  @override
  String get fullScreenEditorEmojiTooltip => 'Emoji';

  @override
  String fullScreenEditorWordCount(int words, int chars) {
    String _temp0 = intl.Intl.pluralLogic(
      words,
      locale: localeName,
      other: '$words words',
      one: '1 word',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chars,
      locale: localeName,
      other: '$chars chars',
      one: '1 char',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get bookmarkImportEmpty => 'No bookmarks found in file';

  @override
  String bookmarkImportAllPresent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookmarks',
      one: '1 bookmark',
    );
    return 'All $_temp0 already present';
  }

  @override
  String bookmarkImportAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookmarks added',
      one: '1 bookmark added',
    );
    return '$_temp0';
  }

  @override
  String bookmarkImportSkippedDup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicates skipped',
      one: '1 duplicate skipped',
    );
    return '$_temp0';
  }

  @override
  String bookmarkImportSkippedInvalid(int count) {
    return '$count invalid skipped';
  }

  @override
  String get spaceZipImportEmpty => 'No posts found in the zip';

  @override
  String spaceZipImportAllPresent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'All $_temp0 already present';
  }

  @override
  String spaceZipImportImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items imported',
      one: '1 item imported',
    );
    return '$_temp0';
  }

  @override
  String spaceZipImportSkippedDup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicates skipped',
      one: '1 duplicate skipped',
    );
    return '$_temp0';
  }

  @override
  String spaceZipImportFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files imported',
      one: '1 file imported',
    );
    return '$_temp0';
  }

  @override
  String get fileViewerImageLoadFailed => 'Failed to load image';

  @override
  String get fileViewerRetry => 'Retry';

  @override
  String fileViewerCannotPlayVideo(String error) {
    return 'Cannot play video: $error';
  }

  @override
  String fileViewerCannotPlayAudio(String error) {
    return 'Cannot play audio: $error';
  }

  @override
  String get fullScreenEditorDefaultTitle => 'Edit';

  @override
  String get hooksTitle => 'Hooks';

  @override
  String get hooksEmpty =>
      'No hooks yet.\nA hook runs an HTTP request when a post is created or edited.';

  @override
  String hooksDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get hooksDeleteBody =>
      'Posts keep their last hook results, but the hook will no longer fire.';

  @override
  String hooksSummary(
      String rules, String triggers, String spaces, String key) {
    return '$rules · $triggers · $spaces · key: $key';
  }

  @override
  String hooksRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String get hooksSpacesAll => 'all spaces';

  @override
  String hooksSpacesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spaces',
      one: '1 space',
    );
    return '$_temp0';
  }

  @override
  String get hookTriggerCreate => 'create';

  @override
  String get hookTriggerEdit => 'edit';

  @override
  String get hookPreviewAlways => 'always';

  @override
  String get hookEditNew => 'New hook';

  @override
  String get hookEditExisting => 'Edit hook';

  @override
  String get hookEditOpenJson => 'Edit as JSON';

  @override
  String get hookEditSave => 'Save';

  @override
  String get hookEditNameLabel => 'Name';

  @override
  String get hookEditKeyLabel => 'Key (used in prior-hook references)';

  @override
  String get hookEditSectionTriggers => 'Triggers';

  @override
  String get hookEditOnCreate => 'On create';

  @override
  String get hookEditOnEdit => 'On edit';

  @override
  String get hookEditSectionSpaces => 'Spaces';

  @override
  String get hookEditSectionPostKinds => 'Post kinds';

  @override
  String get hookEditPostKindNote => 'Notes';

  @override
  String get hookEditPostKindBookmark => 'Bookmarks';

  @override
  String get hookEditTagFilterLabel => 'Tag filter (comma-separated, optional)';

  @override
  String get hookEditTimeoutLabel => 'Timeout (seconds)';

  @override
  String get hookEditSectionVariables => 'Variables';

  @override
  String get hookEditVariablesHelper =>
      'Named constants usable in any template. Reference them as vars.NAME. Values are literal — not re-interpolated. Useful for tokens, chat IDs, or anything reused across rules.';

  @override
  String get hookEditAddVariable => 'Add variable';

  @override
  String get hookEditSectionRules => 'Rules';

  @override
  String get hookEditRulesHelper =>
      'The first rule whose \"when\" evaluates true fires. An empty \"when\" always matches.';

  @override
  String get hookEditAddRule => 'Add rule';

  @override
  String get hookEditShowPreview => 'Preview request';

  @override
  String get hookEditHidePreview => 'Hide preview';

  @override
  String get hookEditPreviewEmpty => 'No complete rules to preview yet.';

  @override
  String hookEditPreviewRuleTitle(int n, String when) {
    return 'Rule $n — $when';
  }

  @override
  String hookEditPreviewMultipart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts',
      one: '1 part',
    );
    return '(multipart: $_temp0)';
  }

  @override
  String get hookEditErrNameRequired => 'Name is required';

  @override
  String get hookEditErrKeyFormat =>
      'Key must be lowercase letters/digits/underscore';

  @override
  String get hookEditErrTriggers => 'Select at least one trigger';

  @override
  String get hookEditErrRules => 'Add at least one rule';

  @override
  String hookEditErrRuleUrl(int n) {
    return 'Rule $n: URL is required';
  }

  @override
  String hookEditErrRuleBuild(int n) {
    return 'Rule $n: could not be built';
  }

  @override
  String hookEditErrVarNameFormat(int n) {
    return 'Variable $n: name must start with a letter or underscore and contain only letters, digits, and underscores';
  }

  @override
  String hookEditErrVarDup(int n, String name) {
    return 'Variable $n: name \"$name\" is duplicated';
  }

  @override
  String hookRuleTitle(int n) {
    return 'Rule $n';
  }

  @override
  String get hookRuleWhenLabel => 'When (optional)';

  @override
  String get hookRuleWhenHint =>
      'post.files.length >= 2 && post.files.length <= 10';

  @override
  String get hookRuleWhenHelper =>
      'First rule whose condition is true fires. Empty always matches.';

  @override
  String get hookRuleMethodLabel => 'Method';

  @override
  String get hookRuleUrlLabel => 'URL template';

  @override
  String get hookRuleBodyLabel => 'Body template';

  @override
  String get hookRuleBodyLabelDisabled =>
      'Body template (disabled — multipart in use)';

  @override
  String get hookRuleHeadersSection => 'Headers';

  @override
  String get hookRuleHeaderNameLabel => 'Name';

  @override
  String get hookRuleHeaderValueLabel => 'Value';

  @override
  String get hookRuleAddHeader => 'Add header';

  @override
  String get hookRuleMultipartSection => 'Multipart parts';

  @override
  String get hookRuleAddPart => 'Add part';

  @override
  String get hookPartNameLabel => 'Name';

  @override
  String get hookPartNameHint => 'chat_id, caption, photo, media…';

  @override
  String get hookPartKindText => 'Text';

  @override
  String get hookPartKindFile => 'File';

  @override
  String get hookPartFilePathLabel =>
      'File path (e.g. post.files.0.id or repeat.file.id)';

  @override
  String get hookPartValueTemplateLabel => 'Value template';

  @override
  String get hookPartRepeatLabel => 'Repeat over post.files';

  @override
  String get hookPartJoinLabel => 'Join (optional)';

  @override
  String get hookPartJoinHint => ',';

  @override
  String get hookPartJoinHelper => 'If set, iterations merge into one field';

  @override
  String get hookPartPrefixLabel => 'Prefix';

  @override
  String get hookPartSuffixLabel => 'Suffix';

  @override
  String get hookPartFilenameLabel => 'Filename override (optional)';

  @override
  String get hookPartRemove => 'Remove';

  @override
  String get hookVarNameLabel => 'Name';

  @override
  String get hookVarNameHint => 'bot_token';

  @override
  String get hookVarValueLabel => 'Value';

  @override
  String get hookVarRemove => 'Remove variable';

  @override
  String get hookJsonTitle => 'Hook JSON';

  @override
  String get hookJsonCopy => 'Copy';

  @override
  String get hookJsonPaste => 'Paste';

  @override
  String get hookJsonFormat => 'Format';

  @override
  String get hookJsonApply => 'Apply';

  @override
  String get hookJsonCopied => 'Copied to clipboard';

  @override
  String get hookJsonHelper =>
      'Edit this hook as JSON. Useful for pasting AI-generated hooks or moving a hook to another vault. The \"id\" field is internal — leave it alone, or omit it to generate a new one on Apply.';

  @override
  String hookJsonErrParse(String error) {
    return 'Not valid JSON: $error';
  }

  @override
  String get hookJsonErrTopLevel => 'Top-level JSON value must be an object';

  @override
  String hookJsonErrInvalid(String error) {
    return 'Invalid hook JSON: $error';
  }

  @override
  String get hookStatusTitle => 'Hook status';

  @override
  String get hookStatusNone => 'No hooks apply to this post.';

  @override
  String hookStatusApplicable(int count) {
    return 'Applicable ($count)';
  }

  @override
  String get hookStatusPast => 'Past runs';

  @override
  String get hookStatusRunAll => 'Run all';

  @override
  String get hookStatusRun => 'Run';

  @override
  String get hookStatusHelper =>
      'Hooks can be fired manually at any time. Templates referencing the trigger variable see the trigger from the hook\'s own settings.';

  @override
  String get hookStatusRunning => 'Running';

  @override
  String get hookStatusNeverFired => 'Never fired';

  @override
  String get hookStatusFailed => 'Failed';

  @override
  String get hookStatusSuccess => 'Success';

  @override
  String hookStatusKey(String key) {
    return 'key: $key';
  }

  @override
  String get hookStatusOrphan => 'This hook no longer exists in the vault.';

  @override
  String hookStatusFired(String when) {
    return 'fired: $when';
  }

  @override
  String hookStatusError(String message) {
    return 'error: $message';
  }

  @override
  String hookStatusStatus(String code) {
    return 'status: $code';
  }

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncEmpty =>
      'No sync repositories configured.\n\nA repository backs up some or all of your spaces to GitHub or GitLab. Exactly one repository is marked primary and additionally backs up vault-level data (hooks).\n\nTap + to add one.';

  @override
  String get syncPushNow => 'Push now';

  @override
  String get syncPullNow => 'Pull now';

  @override
  String get syncMenuEdit => 'Edit…';

  @override
  String get syncMenuSetPrimary => 'Set as primary';

  @override
  String get syncMenuDelete => 'Delete…';

  @override
  String get syncAllSpaces => 'All spaces';

  @override
  String get syncNoSpaces => 'No spaces';

  @override
  String syncSpacesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spaces',
      one: '1 space',
    );
    return '$_temp0';
  }

  @override
  String get syncVaultDataSuffix => '+ vault data';

  @override
  String syncLastSynced(String when) {
    return 'Last synced: $when';
  }

  @override
  String get syncPrimaryBadge => 'PRIMARY';

  @override
  String syncPrimaryNow(String name) {
    return '\"$name\" is now the primary repository';
  }

  @override
  String syncDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get syncDeleteBodyPrimary =>
      'This is the primary repository. Another will be automatically promoted to primary. The remote repository itself is not affected — only this app\'s configuration for it.';

  @override
  String get syncDeleteBody =>
      'The remote repository itself is not affected — only this app\'s configuration for it.';

  @override
  String syncNoTokenSnack(String name) {
    return 'No token for \"$name\". Open Edit to add one.';
  }

  @override
  String syncPushConfirmTitle(String name) {
    return 'Push \"$name\"?';
  }

  @override
  String get syncPushConfirmBody =>
      'Uploads local changes to the remote. Unpulled remote changes will be overwritten.';

  @override
  String syncPullConfirmTitle(String name) {
    return 'Pull \"$name\"?';
  }

  @override
  String get syncPullConfirmBody =>
      'Overwrites local files in this config\'s scope with the remote version. A backup of the vault is saved first.';

  @override
  String get syncPushButton => 'Push';

  @override
  String get syncPullButton => 'Pull';

  @override
  String get syncProgressStarting => 'Starting…';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncDialogClose => 'Close';

  @override
  String syncDialogPushTitle(String name) {
    return 'Push \"$name\"';
  }

  @override
  String syncDialogPullTitle(String name) {
    return 'Pull \"$name\"';
  }

  @override
  String syncPushResultLine(int created, int updated, int deleted) {
    return 'Pushed: $created created, $updated updated, $deleted deleted';
  }

  @override
  String syncPullResultLine(int added, int updated, int deleted) {
    return 'Pulled: $added added, $updated updated, $deleted deleted';
  }

  @override
  String get syncEditNewTitle => 'New repository';

  @override
  String get syncEditExistingTitle => 'Edit repository';

  @override
  String get syncEditSave => 'Save';

  @override
  String get syncEditNameSection => 'NAME';

  @override
  String get syncEditNameHint => 'My backup';

  @override
  String get syncEditNameHelper => 'Display name for this repository';

  @override
  String get syncEditRemoteSection => 'REMOTE';

  @override
  String get syncEditProviderLabel => 'Provider';

  @override
  String get syncEditHostLabel => 'Host (optional)';

  @override
  String syncEditHostHelper(String defaultHost) {
    return 'Leave empty for $defaultHost. For self-hosted, enter the hostname.';
  }

  @override
  String get syncEditOwnerLabel => 'Owner / group';

  @override
  String get syncEditRepoLabel => 'Repository';

  @override
  String get syncEditBranchLabel => 'Branch';

  @override
  String get syncEditPrefixLabel => 'Path prefix (optional)';

  @override
  String get syncEditPrimarySection => 'PRIMARY';

  @override
  String get syncEditPrimarySwitchTitle => 'Set as primary';

  @override
  String get syncEditPrimarySubtitleOn =>
      'This repo also backs up vault-level data (hooks).';

  @override
  String get syncEditPrimarySubtitleOnly =>
      'The only repository is automatically primary.';

  @override
  String get syncEditPrimarySubtitleOff =>
      'Enabling this will demote the current primary.';

  @override
  String get syncEditSpacesSection => 'SPACES';

  @override
  String get syncEditSpacesAll => 'All spaces (including future ones)';

  @override
  String get syncEditSpacesSelected => 'Selected spaces';

  @override
  String get syncEditLoadRemote => 'Load remote spaces';

  @override
  String get syncEditRemoteHintUnloaded =>
      'Tap \"Load remote spaces\" to see spaces that exist on the remote but haven\'t been pulled yet.';

  @override
  String syncEditRemoteHintLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spaces',
      one: '1 space',
    );
    return '$_temp0 on the remote. Remote-only spaces are marked.';
  }

  @override
  String get syncEditRemoteOnlyBadge => 'remote only';

  @override
  String get syncEditRemoteOnlySubtitle =>
      'Not on this device yet — will be pulled on next sync';

  @override
  String syncEditRemoteId(String id) {
    return 'id: $id';
  }

  @override
  String syncEditMissingRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count spaces exist on the remote but are not selected. They will not be pulled by this config until added.',
      one:
          '1 space exists on the remote but is not selected. It will not be pulled by this config until added.',
    );
    return '$_temp0';
  }

  @override
  String get syncEditDriveSection => 'DRIVE OFFLOADING';

  @override
  String get syncEditKeepLocalLabel => 'Keep on disk (files per space)';

  @override
  String get syncEditKeepLocalHelper =>
      'Newest N files stay on disk; older files are offloaded to the remote and fetched on demand. Empty = keep everything.';

  @override
  String get syncEditTokenSection => 'TOKEN';

  @override
  String get syncEditTokenStored => 'Token stored';

  @override
  String get syncEditTokenChange => 'Change';

  @override
  String get syncEditTokenClear => 'Clear';

  @override
  String get syncEditTokenLabel => 'Personal access token';

  @override
  String get syncEditTokenHelperGithub =>
      'Create at github.com/settings/tokens with \"repo\" scope';

  @override
  String get syncEditTokenHelperGitlab =>
      'Create at gitlab.com/-/user_settings/personal_access_tokens with \"api\" scope';

  @override
  String get syncEditVerify => 'Verify access';

  @override
  String get syncEditPushButton => 'Push to remote';

  @override
  String get syncEditPullButton => 'Pull from remote';

  @override
  String get syncEditReenterTitle => 'Re-enter token';

  @override
  String get syncEditReenterBody =>
      'The provider, host, owner, or repo changed. Tokens are scoped to that combination, so the previously saved token can\'t be reused here.\n\nYou\'ll need to enter a new token. Save anyway without a token?';

  @override
  String get syncEditSaveAnyway => 'Save anyway';

  @override
  String get syncEditSaved => 'Saved';

  @override
  String get syncEditAccessVerified => 'Access verified';

  @override
  String get syncEditTokenRequired => 'Enter a token first';

  @override
  String get syncEditPushConfirmTitle => 'Push to remote?';

  @override
  String get syncEditPushConfirmBody =>
      'This uploads the selected spaces (and vault-level data if this is the primary) to the remote. Any changes on the remote that you haven\'t pulled will be overwritten.';

  @override
  String get syncEditPullConfirmTitle => 'Pull from remote?';

  @override
  String get syncEditPullConfirmBody =>
      'This overwrites local files in the selected spaces (and vault-level data if this is the primary) with the remote version. A backup of the vault is saved before pulling.\n\nOn web, the backup is stored in the browser\'s local storage and keeps only the 3 most recent backups.';

  @override
  String get syncEditRemoteLoadTimedOut =>
      'Timed out loading remote spaces. Tap \"Load remote spaces\" to retry.';

  @override
  String syncEditRemoteLoadFailed(String error) {
    return 'Could not load remote spaces: $error';
  }

  @override
  String get recallFilesTitle => 'Recall files';

  @override
  String recallFilesSubtitle(String space, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$space · $_temp0';
  }

  @override
  String get recallFilesListTooltip => 'List view';

  @override
  String get recallFilesGridTooltip => 'Grid view';

  @override
  String get recallFilesEmpty => 'Drive is empty';

  @override
  String get recallFilesNoneSelected => 'No files selected';

  @override
  String recallFilesSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get recallFilesAttach => 'Attach';

  @override
  String get hookEditFallbackName => 'Unnamed hook';

  @override
  String get hookEditFallbackKey => 'unnamed';

  @override
  String get importFileEmpty => 'Selected file is empty';

  @override
  String importFileReadFailed(String error) {
    return 'Could not read file: $error';
  }

  @override
  String get importFilesNoneReadable => 'No readable files selected';

  @override
  String importFilesReadFailed(String error) {
    return 'Could not read files: $error';
  }

  @override
  String get settingsRichEditorSection => 'EDITOR';

  @override
  String get settingsRichEditorTitle => 'Rich text editor';

  @override
  String get settingsRichEditorDescription =>
      'Show formatting toolbar in the composer. When off, the composer uses plain text only.';

  @override
  String get richEditorBold => 'Bold';

  @override
  String get richEditorItalic => 'Italic';

  @override
  String get richEditorUnderline => 'Underline';

  @override
  String get richEditorStrikethrough => 'Strikethrough';

  @override
  String get richEditorInlineCode => 'Inline code';

  @override
  String get richEditorClearFormatting => 'Clear formatting';

  @override
  String get composerRichInPlainWarning =>
      'This post has rich formatting. Editing in plain text mode will remove bold, italic, underline, strikethrough, and inline code.';

  @override
  String get composerRichDraftInPlainWarning =>
      'This draft was saved with the rich editor. Editing here will remove its formatting.';
}
