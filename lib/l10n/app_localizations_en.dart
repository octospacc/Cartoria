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
}
