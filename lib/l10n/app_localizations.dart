import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Cartoria'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get onboardingWelcome;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingCreateFirstSpace.
  ///
  /// In en, this message translates to:
  /// **'Create your first space'**
  String get onboardingCreateFirstSpace;

  /// No description provided for @onboardingBody.
  ///
  /// In en, this message translates to:
  /// **'A space holds its own notes, bookmarks, and files. Spaces are independent — you can add more later.'**
  String get onboardingBody;

  /// No description provided for @onboardingSpaceName.
  ///
  /// In en, this message translates to:
  /// **'Space name'**
  String get onboardingSpaceName;

  /// No description provided for @onboardingCreateSpace.
  ///
  /// In en, this message translates to:
  /// **'Create space'**
  String get onboardingCreateSpace;

  /// No description provided for @spacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get spacesTitle;

  /// No description provided for @spacesHooksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hooks'**
  String get spacesHooksTooltip;

  /// No description provided for @spacesSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get spacesSyncTooltip;

  /// No description provided for @spacesImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'New space from file…'**
  String get spacesImportTooltip;

  /// No description provided for @spacesSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get spacesSettingsTooltip;

  /// No description provided for @spacesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No spaces yet'**
  String get spacesEmpty;

  /// No description provided for @spacesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first space, or import from a file using the icon at the top.'**
  String get spacesEmptyHint;

  /// No description provided for @spacesEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get spacesEmptyLabel;

  /// No description provided for @spacesStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get spacesStatistics;

  /// No description provided for @spacesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit space…'**
  String get spacesEdit;

  /// No description provided for @spacesExport.
  ///
  /// In en, this message translates to:
  /// **'Export space…'**
  String get spacesExport;

  /// No description provided for @spacesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete space…'**
  String get spacesDelete;

  /// No description provided for @spacesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String spacesDeleteTitle(String name);

  /// No description provided for @spacesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every post and file in this space. Cannot be undone.'**
  String get spacesDeleteBody;

  /// No description provided for @spacesCountNotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{1 note} other{{count} notes}}'**
  String spacesCountNotes(int count);

  /// No description provided for @spacesCountBookmarks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{1 bookmark} other{{count} bookmarks}}'**
  String spacesCountBookmarks(int count);

  /// No description provided for @spacesCountReplies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{1 reply} other{{count} replies}}'**
  String spacesCountReplies(int count);

  /// No description provided for @spacesCountFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{} =1{1 file} other{{count} files}}'**
  String spacesCountFiles(int count);

  /// No description provided for @spaceDialogNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New space'**
  String get spaceDialogNewTitle;

  /// No description provided for @spaceDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit space'**
  String get spaceDialogEditTitle;

  /// No description provided for @spaceDialogNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get spaceDialogNameLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Language used by the app interface. Also used for spell check in the composer.'**
  String get settingsLanguageDescription;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get settingsLanguageItalian;

  /// No description provided for @settingsBackupsSection.
  ///
  /// In en, this message translates to:
  /// **'BACKUPS'**
  String get settingsBackupsSection;

  /// No description provided for @settingsBackupsDescription.
  ///
  /// In en, this message translates to:
  /// **'A backup of the vault is created before each pull, so a bad pull cannot destroy unpushed local changes. Old backups are deleted automatically beyond the retention limit.'**
  String get settingsBackupsDescription;

  /// No description provided for @settingsRetentionLabel.
  ///
  /// In en, this message translates to:
  /// **'Retention (number of backups)'**
  String get settingsRetentionLabel;

  /// No description provided for @settingsRetentionHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the default. Set to 0 to disable pre-pull backups entirely.'**
  String get settingsRetentionHelper;

  /// No description provided for @settingsRetentionSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsRetentionSaveTooltip;

  /// No description provided for @settingsRetentionCurrent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Currently keeping up to 1 backup} other{Currently keeping up to {count} backups}}'**
  String settingsRetentionCurrent(int count);

  /// No description provided for @settingsBackupsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading backups…'**
  String get settingsBackupsLoading;

  /// No description provided for @settingsBackupsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No backups} =1{1 backup} other{{count} backups}}'**
  String settingsBackupsCount(int count);

  /// No description provided for @settingsBackupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backups yet. Backups are created automatically before each pull.'**
  String get settingsBackupsEmpty;

  /// No description provided for @settingsBackupsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get settingsBackupsClearAll;

  /// No description provided for @settingsBackupsExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsBackupsExportTooltip;

  /// No description provided for @settingsBackupsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsBackupsDeleteTooltip;

  /// No description provided for @settingsBackupsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Clear 1 backup?} other{Clear {count} backups?}}'**
  String settingsBackupsClearTitle(int count);

  /// No description provided for @settingsBackupsClearBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes every pre-pull backup. Current vault data is not affected. This cannot be undone.'**
  String get settingsBackupsClearBody;

  /// No description provided for @settingsBackupDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String settingsBackupDeleteTitle(String name);

  /// No description provided for @settingsBackupDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes this backup. Other backups and current vault data are not affected.'**
  String get settingsBackupDeleteBody;

  /// No description provided for @settingsRetentionSaved.
  ///
  /// In en, this message translates to:
  /// **'Retention set to {count}'**
  String settingsRetentionSaved(int count);

  /// No description provided for @settingsRetentionReset.
  ///
  /// In en, this message translates to:
  /// **'Retention reset to default'**
  String get settingsRetentionReset;

  /// No description provided for @settingsRetentionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Pre-pull backups disabled'**
  String get settingsRetentionDisabled;

  /// No description provided for @settingsRetentionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Retention must be a non-negative integer'**
  String get settingsRetentionInvalid;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String settingsSaveFailed(String error);

  /// No description provided for @settingsListBackupsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not list backups: {error}'**
  String settingsListBackupsFailed(String error);

  /// No description provided for @settingsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String settingsExportFailed(String error);

  /// No description provided for @settingsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String settingsDeleteFailed(String error);

  /// No description provided for @spaceImportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type'**
  String get spaceImportUnsupported;

  /// No description provided for @spaceImportSinglePost.
  ///
  /// In en, this message translates to:
  /// **'Single-post file — open a space and use Import… there'**
  String get spaceImportSinglePost;

  /// No description provided for @spaceImportNoBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks found'**
  String get spaceImportNoBookmarks;

  /// No description provided for @spaceImportDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get spaceImportDetails;

  /// No description provided for @spaceImportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing imported'**
  String get spaceImportNothing;

  /// No description provided for @spaceImportSummary.
  ///
  /// In en, this message translates to:
  /// **'{ok} imported, {failed} failed, {cancelled} cancelled'**
  String spaceImportSummary(int ok, int failed, int cancelled);

  /// No description provided for @spaceImportSummaryOkFailed.
  ///
  /// In en, this message translates to:
  /// **'{ok} file{ok, plural, =1{} other{s}} imported · {failed} failed'**
  String spaceImportSummaryOkFailed(int ok, int failed);

  /// No description provided for @spaceImportSummaryOk.
  ///
  /// In en, this message translates to:
  /// **'{ok} file{ok, plural, =1{} other{s}} imported'**
  String spaceImportSummaryOk(int ok);

  /// No description provided for @spaceImportSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'{failed} failed'**
  String spaceImportSummaryFailed(int failed);

  /// No description provided for @spaceImportSummaryCancelled.
  ///
  /// In en, this message translates to:
  /// **'{cancelled} cancelled'**
  String spaceImportSummaryCancelled(int cancelled);

  /// No description provided for @spaceImportZipResult.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\"'**
  String spaceImportZipResult(String name);

  /// No description provided for @spaceImportBookmarksResult.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} into \"{name}\"'**
  String spaceImportBookmarksResult(int count, String name);

  /// No description provided for @spaceImportBookmarksDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import bookmarks'**
  String get spaceImportBookmarksDialogTitle;

  /// No description provided for @spaceImportDefaultBookmarksName.
  ///
  /// In en, this message translates to:
  /// **'Imported Bookmarks'**
  String get spaceImportDefaultBookmarksName;

  /// No description provided for @feedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search this space…'**
  String get feedSearchHint;

  /// No description provided for @feedSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get feedSearchClear;

  /// No description provided for @feedSearchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get feedSearchClose;

  /// No description provided for @feedSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String feedSearchNoResults(String query);

  /// No description provided for @feedSearchMatches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String feedSearchMatches(int count);

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Write a note or save a link.'**
  String get feedEmpty;

  /// No description provided for @feedSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get feedSelect;

  /// No description provided for @feedDrive.
  ///
  /// In en, this message translates to:
  /// **'Drive'**
  String get feedDrive;

  /// No description provided for @feedExitSelection.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get feedExitSelection;

  /// No description provided for @feedSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String feedSelectedCount(int count);

  /// No description provided for @feedSelectPosts.
  ///
  /// In en, this message translates to:
  /// **'Select posts'**
  String get feedSelectPosts;

  /// No description provided for @feedDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get feedDeleteSelected;

  /// No description provided for @feedDeleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 post?} other{Delete {count} posts?}}'**
  String feedDeleteSelectedTitle(int count);

  /// No description provided for @feedDeleteSelectedBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get feedDeleteSelectedBody;

  /// No description provided for @feedDeleteSelectedOrphaned.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reply will become top-level.} other{{count} replies will become top-level.}}'**
  String feedDeleteSelectedOrphaned(int count);

  /// No description provided for @feedMenuImport.
  ///
  /// In en, this message translates to:
  /// **'Import…'**
  String get feedMenuImport;

  /// No description provided for @feedMenuImportSource.
  ///
  /// In en, this message translates to:
  /// **'Paste post source…'**
  String get feedMenuImportSource;

  /// No description provided for @feedImportOneFile.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\"'**
  String feedImportOneFile(String name);

  /// No description provided for @feedImportPost.
  ///
  /// In en, this message translates to:
  /// **'Post imported'**
  String get feedImportPost;

  /// No description provided for @feedImportBookmarksFound.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks found in file'**
  String get feedImportBookmarksFound;

  /// No description provided for @feedImportFilesSummary.
  ///
  /// In en, this message translates to:
  /// **'{ok} imported'**
  String feedImportFilesSummary(int ok);

  /// No description provided for @feedImportErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error} other{{count} errors}}'**
  String feedImportErrorsTitle(int count);

  /// No description provided for @feedUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type'**
  String get feedUnsupportedFile;

  /// No description provided for @feedPasteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste post source'**
  String get feedPasteDialogTitle;

  /// No description provided for @feedPasteDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a Cartoria post file — the same format as entries/<id>.html: a <!--- … ---> JSON frontmatter block followed by the HTML body. A fresh ID is generated if none is present.'**
  String get feedPasteDialogHint;

  /// No description provided for @composerNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get composerNote;

  /// No description provided for @composerLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get composerLink;

  /// No description provided for @composerBodyHintNote.
  ///
  /// In en, this message translates to:
  /// **'Write something…'**
  String get composerBodyHintNote;

  /// No description provided for @composerBodyHintBookmark.
  ///
  /// In en, this message translates to:
  /// **'Why save this?'**
  String get composerBodyHintBookmark;

  /// No description provided for @composerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get composerUrlHint;

  /// No description provided for @composerEmojiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get composerEmojiTooltip;

  /// No description provided for @composerHooksSkip.
  ///
  /// In en, this message translates to:
  /// **'Hooks skipped this save — tap to re-enable'**
  String get composerHooksSkip;

  /// No description provided for @composerHooksRun.
  ///
  /// In en, this message translates to:
  /// **'Hooks will run on save — tap to skip'**
  String get composerHooksRun;

  /// No description provided for @composerExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand to full screen'**
  String get composerExpand;

  /// No description provided for @composerAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get composerAttach;

  /// No description provided for @composerSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSend;

  /// No description provided for @composerDiscardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get composerDiscardDraft;

  /// No description provided for @composerSetDateTime.
  ///
  /// In en, this message translates to:
  /// **'Set post date/time'**
  String get composerSetDateTime;

  /// No description provided for @composerNewPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get composerNewPost;

  /// No description provided for @composerReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get composerReply;

  /// No description provided for @composerQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get composerQuote;

  /// No description provided for @composerPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get composerPost;

  /// No description provided for @composerEditing.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get composerEditing;

  /// No description provided for @composerQuoting.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get composerQuoting;

  /// No description provided for @composerReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to: {preview}'**
  String composerReplyingTo(String preview);

  /// No description provided for @composerQuotingPreview.
  ///
  /// In en, this message translates to:
  /// **'Quoting: {preview}'**
  String composerQuotingPreview(String preview);

  /// No description provided for @composerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get composerUrlLabel;

  /// No description provided for @composerRefreshMetadata.
  ///
  /// In en, this message translates to:
  /// **'Refresh metadata'**
  String get composerRefreshMetadata;

  /// No description provided for @composerTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get composerTitleLabel;

  /// No description provided for @composerDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get composerDescriptionLabel;

  /// No description provided for @composerBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get composerBodyLabel;

  /// No description provided for @composerBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Write the body…'**
  String get composerBodyHint;

  /// No description provided for @composerPostedAt.
  ///
  /// In en, this message translates to:
  /// **'Posted at'**
  String get composerPostedAt;

  /// No description provided for @composerPostedNow.
  ///
  /// In en, this message translates to:
  /// **'Now (default)'**
  String get composerPostedNow;

  /// No description provided for @composerSetTime.
  ///
  /// In en, this message translates to:
  /// **'Set…'**
  String get composerSetTime;

  /// No description provided for @composerChangeTime.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get composerChangeTime;

  /// No description provided for @composerResetTime.
  ///
  /// In en, this message translates to:
  /// **'Reset to now'**
  String get composerResetTime;

  /// No description provided for @composerHooksRunOnSave.
  ///
  /// In en, this message translates to:
  /// **'Run hooks on save'**
  String get composerHooksRunOnSave;

  /// No description provided for @composerHooksWillSkip.
  ///
  /// In en, this message translates to:
  /// **'Hooks will be skipped. You can trigger them later from the post menu.'**
  String get composerHooksWillSkip;

  /// No description provided for @composerHooksWillRun.
  ///
  /// In en, this message translates to:
  /// **'Matching hooks will fire when you tap {action}.'**
  String composerHooksWillRun(String action);

  /// No description provided for @composerAddFile.
  ///
  /// In en, this message translates to:
  /// **'Add file'**
  String get composerAddFile;

  /// No description provided for @composerUnsavedDraft.
  ///
  /// In en, this message translates to:
  /// **'Unsaved draft'**
  String get composerUnsavedDraft;

  /// No description provided for @composerUnsavedDraftFrom.
  ///
  /// In en, this message translates to:
  /// **'Unsaved draft from {when}'**
  String composerUnsavedDraftFrom(String when);

  /// No description provided for @composerDraftReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get composerDraftReset;

  /// No description provided for @composerMetadataFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch metadata'**
  String get composerMetadataFetchFailed;

  /// No description provided for @composerUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a URL first'**
  String get composerUrlRequired;

  /// No description provided for @composerBookmarkNeedsUrl.
  ///
  /// In en, this message translates to:
  /// **'A bookmark needs a URL'**
  String get composerBookmarkNeedsUrl;

  /// No description provided for @composerEscapeBack.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get composerEscapeBack;

  /// No description provided for @composerRelativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get composerRelativeJustNow;

  /// No description provided for @composerRelativeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String composerRelativeMinutes(int count);

  /// No description provided for @composerRelativeHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String composerRelativeHours(int count);

  /// No description provided for @composerRelativeDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String composerRelativeDays(int count);

  /// No description provided for @composerFullScreenNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get composerFullScreenNoteTitle;

  /// No description provided for @composerFullScreenNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Write something…'**
  String get composerFullScreenNoteHint;

  /// No description provided for @composerFullScreenBookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Why save this'**
  String get composerFullScreenBookmarkTitle;

  /// No description provided for @composerFullScreenBookmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Why save this?'**
  String get composerFullScreenBookmarkHint;

  /// No description provided for @composerFullScreenEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit post body'**
  String get composerFullScreenEditTitle;

  /// No description provided for @composerFullScreenReplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Reply body'**
  String get composerFullScreenReplyTitle;

  /// No description provided for @composerFullScreenQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Quote body'**
  String get composerFullScreenQuoteTitle;

  /// No description provided for @composerFullScreenNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Post body'**
  String get composerFullScreenNewTitle;

  /// No description provided for @attachmentUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload new files'**
  String get attachmentUpload;

  /// No description provided for @attachmentPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get attachmentPaste;

  /// No description provided for @attachmentRecall.
  ///
  /// In en, this message translates to:
  /// **'Recall from drive'**
  String get attachmentRecall;

  /// No description provided for @attachmentPasteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No image or file found in clipboard. On web, try pressing Ctrl+V in the composer instead.'**
  String get attachmentPasteEmpty;

  /// No description provided for @attachmentPasteFailed.
  ///
  /// In en, this message translates to:
  /// **'Paste failed: {error}'**
  String attachmentPasteFailed(String error);

  /// No description provided for @attachmentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String attachmentUploadFailed(String error);

  /// No description provided for @attachmentUploadFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} file{count, plural, =1{} other{s}} failed to upload'**
  String attachmentUploadFailedCount(int count);

  /// No description provided for @attachmentDriveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Drive is empty'**
  String get attachmentDriveEmpty;

  /// No description provided for @postReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get postReply;

  /// No description provided for @postQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get postQuote;

  /// No description provided for @postEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get postEdit;

  /// No description provided for @postSource.
  ///
  /// In en, this message translates to:
  /// **'Show source…'**
  String get postSource;

  /// No description provided for @postHookStatus.
  ///
  /// In en, this message translates to:
  /// **'Hook status…'**
  String get postHookStatus;

  /// No description provided for @postDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get postDelete;

  /// No description provided for @postShowMoreReplies.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more {count, plural, =1{reply} other{replies}}'**
  String postShowMoreReplies(int count);

  /// No description provided for @postHideReplies.
  ///
  /// In en, this message translates to:
  /// **'Hide {count} {count, plural, =1{reply} other{replies}}'**
  String postHideReplies(int count);

  /// No description provided for @postShowFewer.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get postShowFewer;

  /// No description provided for @postRepliesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{reply} other{replies}}'**
  String postRepliesCount(int count);

  /// No description provided for @postDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get postDeleteNote;

  /// No description provided for @postDeleteBookmark.
  ///
  /// In en, this message translates to:
  /// **'Delete this bookmark?'**
  String get postDeleteBookmark;

  /// No description provided for @postDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Attached files stay in the drive. Replies will become top-level. Cannot be undone.'**
  String get postDeleteBody;

  /// No description provided for @postQuotedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Quoted post unavailable'**
  String get postQuotedUnavailable;

  /// No description provided for @postQuotedFromSpace.
  ///
  /// In en, this message translates to:
  /// **'Quoted from this space'**
  String get postQuotedFromSpace;

  /// No description provided for @postQuotedIncludesAnother.
  ///
  /// In en, this message translates to:
  /// **'↪ includes another quote'**
  String get postQuotedIncludesAnother;

  /// No description provided for @postQuotedExternal.
  ///
  /// In en, this message translates to:
  /// **'External quote'**
  String get postQuotedExternal;

  /// No description provided for @postQuotedOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to view the quoted post'**
  String get postQuotedOpenHint;

  /// No description provided for @postHookRunning.
  ///
  /// In en, this message translates to:
  /// **'Hooks running…'**
  String get postHookRunning;

  /// No description provided for @postHookSuccess.
  ///
  /// In en, this message translates to:
  /// **'Hooks succeeded'**
  String get postHookSuccess;

  /// No description provided for @postHookFailed.
  ///
  /// In en, this message translates to:
  /// **'Hooks failed — tap for details'**
  String get postHookFailed;

  /// No description provided for @postEdited.
  ///
  /// In en, this message translates to:
  /// **'· edited {when}'**
  String postEdited(String when);

  /// No description provided for @postShowQuotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 quote} other{{count} quotes}}'**
  String postShowQuotes(int count);

  /// No description provided for @postHideQuotes.
  ///
  /// In en, this message translates to:
  /// **'Hide {count, plural, =1{1 quote} other{{count} quotes}}'**
  String postHideQuotes(int count);

  /// No description provided for @postQuotedByHeader.
  ///
  /// In en, this message translates to:
  /// **'QUOTED BY'**
  String get postQuotedByHeader;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
