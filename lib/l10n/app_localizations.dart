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

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Startup error'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Cartoria could not finish starting up. This is usually a permissions or disk issue, not a bug in the app.'**
  String get startupErrorBody;

  /// No description provided for @startupErrorStack.
  ///
  /// In en, this message translates to:
  /// **'Stack:'**
  String get startupErrorStack;

  /// No description provided for @driveTitle.
  ///
  /// In en, this message translates to:
  /// **'Drive'**
  String get driveTitle;

  /// No description provided for @driveMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get driveMoreTooltip;

  /// No description provided for @driveOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get driveOpen;

  /// No description provided for @driveUsageAction.
  ///
  /// In en, this message translates to:
  /// **'Show posts using this file…'**
  String get driveUsageAction;

  /// No description provided for @driveShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share / download'**
  String get driveShareAction;

  /// No description provided for @driveDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get driveDeleteAction;

  /// No description provided for @driveSelectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select files'**
  String get driveSelectFiles;

  /// No description provided for @driveSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String driveSelectedCount(int count);

  /// No description provided for @driveExitSelection.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get driveExitSelection;

  /// No description provided for @driveSelectUnused.
  ///
  /// In en, this message translates to:
  /// **'Select unused'**
  String get driveSelectUnused;

  /// No description provided for @driveDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get driveDeleteSelected;

  /// No description provided for @driveSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get driveSearchTooltip;

  /// No description provided for @driveSearchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get driveSearchClose;

  /// No description provided for @driveSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search files…'**
  String get driveSearchHint;

  /// No description provided for @driveClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get driveClear;

  /// No description provided for @driveGridTooltip.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get driveGridTooltip;

  /// No description provided for @driveListTooltip.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get driveListTooltip;

  /// No description provided for @driveEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No files yet.\nUpload one here, or attach from a post.'**
  String get driveEmptyState;

  /// No description provided for @driveNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No files match \"{query}\".'**
  String driveNoMatch(String query);

  /// No description provided for @driveSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String driveSummaryTotal(int count);

  /// No description provided for @driveSummaryOffloaded.
  ///
  /// In en, this message translates to:
  /// **'{count} offloaded'**
  String driveSummaryOffloaded(int count);

  /// No description provided for @driveSummaryUnused.
  ///
  /// In en, this message translates to:
  /// **'{count} unused'**
  String driveSummaryUnused(int count);

  /// No description provided for @driveUsageUsed.
  ///
  /// In en, this message translates to:
  /// **'used'**
  String get driveUsageUsed;

  /// No description provided for @driveUsageUnused.
  ///
  /// In en, this message translates to:
  /// **'unused'**
  String get driveUsageUnused;

  /// No description provided for @driveStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get driveStatusMissing;

  /// No description provided for @driveStatusRemote.
  ///
  /// In en, this message translates to:
  /// **'remote'**
  String get driveStatusRemote;

  /// No description provided for @driveDeleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count, plural, =1{1 file} other{{count} files}}?'**
  String driveDeleteSelectedTitle(int count);

  /// No description provided for @driveDeleteSelectedBody.
  ///
  /// In en, this message translates to:
  /// **'Posts that reference these files will lose the attachments. This cannot be undone.'**
  String get driveDeleteSelectedBody;

  /// No description provided for @driveDeleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String driveDeleteFileTitle(String name);

  /// No description provided for @driveDeleteFileBody.
  ///
  /// In en, this message translates to:
  /// **'Posts that reference this file will lose the attachment.'**
  String get driveDeleteFileBody;

  /// No description provided for @driveMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is missing'**
  String driveMissingTitle(String name);

  /// No description provided for @driveMissingBody.
  ///
  /// In en, this message translates to:
  /// **'This file is referenced by one or more posts, but its content isn\'t stored anywhere on this device or the sync remote.\n\nYou can restore it by re-importing the full export it came from, pulling from the sync remote if it still has the file, or by picking a replacement file from this device.'**
  String get driveMissingBody;

  /// No description provided for @driveUploadReplacement.
  ///
  /// In en, this message translates to:
  /// **'Upload replacement…'**
  String get driveUploadReplacement;

  /// No description provided for @driveRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored \"{name}\"'**
  String driveRestored(String name);

  /// No description provided for @driveRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String driveRestoreFailed(String error);

  /// No description provided for @driveUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String driveUploadFailed(String error);

  /// No description provided for @driveUploadSummaryAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file uploaded} other{{count} files uploaded}}'**
  String driveUploadSummaryAdded(int count);

  /// No description provided for @driveUploadSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file failed} other{{count} files failed}}'**
  String driveUploadSummaryFailed(int count);

  /// No description provided for @driveUploadNothing.
  ///
  /// In en, this message translates to:
  /// **'No files uploaded'**
  String get driveUploadNothing;

  /// No description provided for @driveUploadDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file failed to upload} other{{count} files failed to upload}}'**
  String driveUploadDialogTitle(int count);

  /// No description provided for @drivePastedFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Added {count, plural, =1{1 file} other{{count} files}} from clipboard.'**
  String drivePastedFromClipboard(int count);

  /// No description provided for @drivePasteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No image or file found in clipboard. On web, try pasting into a composer.'**
  String get drivePasteEmpty;

  /// No description provided for @drivePasteFailed.
  ///
  /// In en, this message translates to:
  /// **'Paste failed: {error}'**
  String drivePasteFailed(String error);

  /// No description provided for @driveDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download from remote?'**
  String get driveDownloadTitle;

  /// No description provided for @driveDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is not on this device. Fetch it now?'**
  String driveDownloadBody(String name);

  /// No description provided for @driveDownloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get driveDownloadConfirm;

  /// No description provided for @driveDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String driveDownloadFailed(String error);

  /// No description provided for @linkPreviewOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String linkPreviewOpenFailed(String url);

  /// No description provided for @linkPreviewOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open link: {error}'**
  String linkPreviewOpenError(String error);

  /// No description provided for @postBodyImagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'[image]'**
  String get postBodyImagePlaceholder;

  /// No description provided for @postBodyImagePlaceholderAlt.
  ///
  /// In en, this message translates to:
  /// **'[image: {alt}]'**
  String postBodyImagePlaceholderAlt(String alt);

  /// No description provided for @postBodyImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get postBodyImageFailed;

  /// No description provided for @postBodyOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String postBodyOpenFailed(String url);

  /// No description provided for @postBodyOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open link: {error}'**
  String postBodyOpenError(String error);

  /// No description provided for @emojiTitle.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emojiTitle;

  /// No description provided for @emojiCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get emojiCloseTooltip;

  /// No description provided for @fileUsageEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Not referenced by any post'**
  String get fileUsageEmptyTitle;

  /// No description provided for @fileUsageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 post references this file} other{{count} posts reference this file}}'**
  String fileUsageCount(int count);

  /// No description provided for @fileUsageNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts reference this file.'**
  String get fileUsageNoPosts;

  /// No description provided for @fileUsageNoText.
  ///
  /// In en, this message translates to:
  /// **'(no text)'**
  String get fileUsageNoText;

  /// No description provided for @postSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Source · {shortId}…'**
  String postSourceTitle(String shortId);

  /// No description provided for @postSourceCopied.
  ///
  /// In en, this message translates to:
  /// **'Source copied'**
  String get postSourceCopied;

  /// No description provided for @postSourceCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get postSourceCopy;

  /// No description provided for @postSourceReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read source: {error}'**
  String postSourceReadFailed(String error);

  /// No description provided for @spaceActionsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export \"{name}\"'**
  String spaceActionsExportTitle(String name);

  /// No description provided for @spaceActionsFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get spaceActionsFull;

  /// No description provided for @spaceActionsFullBody.
  ///
  /// In en, this message translates to:
  /// **'Includes every file. Offloaded files are {count, plural, =0{none} =1{1 and downloaded} other{{count} and downloaded}} from the sync remote before the zip is built. Slowest, but the export is self-contained.'**
  String spaceActionsFullBody(int count);

  /// No description provided for @spaceActionsOnDisk.
  ///
  /// In en, this message translates to:
  /// **'On-disk only'**
  String get spaceActionsOnDisk;

  /// No description provided for @spaceActionsOnDiskBody.
  ///
  /// In en, this message translates to:
  /// **'Includes files currently stored on this device. {count, plural, =0{No files are offloaded.} =1{1 offloaded file skipped.} other{{count} offloaded files skipped.}} File references are preserved in the export; re-importing the full zip (or syncing) later can restore the missing blobs.'**
  String spaceActionsOnDiskBody(int count);

  /// No description provided for @spaceActionsNoMedia.
  ///
  /// In en, this message translates to:
  /// **'Without media'**
  String get spaceActionsNoMedia;

  /// No description provided for @spaceActionsNoMediaBody.
  ///
  /// In en, this message translates to:
  /// **'No files at all. Only the text (notes, bookmarks) and file references. Smallest export; every file will appear as missing on import until restored.'**
  String get spaceActionsNoMediaBody;

  /// No description provided for @spaceActionsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String spaceActionsExportFailed(String error);

  /// No description provided for @spaceStatsCouldNotCompute.
  ///
  /// In en, this message translates to:
  /// **'Could not compute stats: {error}'**
  String spaceStatsCouldNotCompute(String error);

  /// No description provided for @spaceStatsContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get spaceStatsContent;

  /// No description provided for @spaceStatsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get spaceStatsTotal;

  /// No description provided for @spaceStatsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get spaceStatsNotes;

  /// No description provided for @spaceStatsBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get spaceStatsBookmarks;

  /// No description provided for @spaceStatsReplies.
  ///
  /// In en, this message translates to:
  /// **'Replies (nested)'**
  String get spaceStatsReplies;

  /// No description provided for @spaceStatsDrive.
  ///
  /// In en, this message translates to:
  /// **'Drive'**
  String get spaceStatsDrive;

  /// No description provided for @spaceStatsFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get spaceStatsFiles;

  /// No description provided for @spaceStatsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get spaceStatsStorage;

  /// No description provided for @spaceStatsSpaceSize.
  ///
  /// In en, this message translates to:
  /// **'Space size'**
  String get spaceStatsSpaceSize;

  /// No description provided for @spaceStatsLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get spaceStatsLocation;

  /// No description provided for @fullScreenEditorEmojiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get fullScreenEditorEmojiTooltip;

  /// No description provided for @fullScreenEditorWordCount.
  ///
  /// In en, this message translates to:
  /// **'{words, plural, =1{1 word} other{{words} words}} · {chars, plural, =1{1 char} other{{chars} chars}}'**
  String fullScreenEditorWordCount(int words, int chars);

  /// No description provided for @bookmarkImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks found in file'**
  String get bookmarkImportEmpty;

  /// No description provided for @bookmarkImportAllPresent.
  ///
  /// In en, this message translates to:
  /// **'All {count, plural, =1{1 bookmark} other{{count} bookmarks}} already present'**
  String bookmarkImportAllPresent(int count);

  /// No description provided for @bookmarkImportAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bookmark added} other{{count} bookmarks added}}'**
  String bookmarkImportAdded(int count);

  /// No description provided for @bookmarkImportSkippedDup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 duplicate skipped} other{{count} duplicates skipped}}'**
  String bookmarkImportSkippedDup(int count);

  /// No description provided for @bookmarkImportSkippedInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count} invalid skipped'**
  String bookmarkImportSkippedInvalid(int count);

  /// No description provided for @spaceZipImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts found in the zip'**
  String get spaceZipImportEmpty;

  /// No description provided for @spaceZipImportAllPresent.
  ///
  /// In en, this message translates to:
  /// **'All {count, plural, =1{1 item} other{{count} items}} already present'**
  String spaceZipImportAllPresent(int count);

  /// No description provided for @spaceZipImportImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item imported} other{{count} items imported}}'**
  String spaceZipImportImported(int count);

  /// No description provided for @spaceZipImportSkippedDup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 duplicate skipped} other{{count} duplicates skipped}}'**
  String spaceZipImportSkippedDup(int count);

  /// No description provided for @spaceZipImportFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file imported} other{{count} files imported}}'**
  String spaceZipImportFiles(int count);

  /// No description provided for @fileViewerImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get fileViewerImageLoadFailed;

  /// No description provided for @fileViewerRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get fileViewerRetry;

  /// No description provided for @fileViewerCannotPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Cannot play video: {error}'**
  String fileViewerCannotPlayVideo(String error);

  /// No description provided for @fileViewerCannotPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Cannot play audio: {error}'**
  String fileViewerCannotPlayAudio(String error);

  /// No description provided for @fullScreenEditorDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get fullScreenEditorDefaultTitle;

  /// No description provided for @hooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Hooks'**
  String get hooksTitle;

  /// No description provided for @hooksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No hooks yet.\nA hook runs an HTTP request when a post is created or edited.'**
  String get hooksEmpty;

  /// No description provided for @hooksDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String hooksDeleteTitle(String name);

  /// No description provided for @hooksDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Posts keep their last hook results, but the hook will no longer fire.'**
  String get hooksDeleteBody;

  /// No description provided for @hooksSummary.
  ///
  /// In en, this message translates to:
  /// **'{rules} · {triggers} · {spaces} · key: {key}'**
  String hooksSummary(String rules, String triggers, String spaces, String key);

  /// No description provided for @hooksRulesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule} other{{count} rules}}'**
  String hooksRulesCount(int count);

  /// No description provided for @hooksSpacesAll.
  ///
  /// In en, this message translates to:
  /// **'all spaces'**
  String get hooksSpacesAll;

  /// No description provided for @hooksSpacesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 space} other{{count} spaces}}'**
  String hooksSpacesCount(int count);

  /// No description provided for @hookTriggerCreate.
  ///
  /// In en, this message translates to:
  /// **'create'**
  String get hookTriggerCreate;

  /// No description provided for @hookTriggerEdit.
  ///
  /// In en, this message translates to:
  /// **'edit'**
  String get hookTriggerEdit;

  /// No description provided for @hookPreviewAlways.
  ///
  /// In en, this message translates to:
  /// **'always'**
  String get hookPreviewAlways;

  /// No description provided for @hookEditNew.
  ///
  /// In en, this message translates to:
  /// **'New hook'**
  String get hookEditNew;

  /// No description provided for @hookEditExisting.
  ///
  /// In en, this message translates to:
  /// **'Edit hook'**
  String get hookEditExisting;

  /// No description provided for @hookEditOpenJson.
  ///
  /// In en, this message translates to:
  /// **'Edit as JSON'**
  String get hookEditOpenJson;

  /// No description provided for @hookEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get hookEditSave;

  /// No description provided for @hookEditNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get hookEditNameLabel;

  /// No description provided for @hookEditKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key (used in prior-hook references)'**
  String get hookEditKeyLabel;

  /// No description provided for @hookEditSectionTriggers.
  ///
  /// In en, this message translates to:
  /// **'Triggers'**
  String get hookEditSectionTriggers;

  /// No description provided for @hookEditOnCreate.
  ///
  /// In en, this message translates to:
  /// **'On create'**
  String get hookEditOnCreate;

  /// No description provided for @hookEditOnEdit.
  ///
  /// In en, this message translates to:
  /// **'On edit'**
  String get hookEditOnEdit;

  /// No description provided for @hookEditSectionSpaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get hookEditSectionSpaces;

  /// No description provided for @hookEditSectionPostKinds.
  ///
  /// In en, this message translates to:
  /// **'Post kinds'**
  String get hookEditSectionPostKinds;

  /// No description provided for @hookEditPostKindNote.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get hookEditPostKindNote;

  /// No description provided for @hookEditPostKindBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get hookEditPostKindBookmark;

  /// No description provided for @hookEditTagFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag filter (comma-separated, optional)'**
  String get hookEditTagFilterLabel;

  /// No description provided for @hookEditTimeoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get hookEditTimeoutLabel;

  /// No description provided for @hookEditSectionVariables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get hookEditSectionVariables;

  /// No description provided for @hookEditVariablesHelper.
  ///
  /// In en, this message translates to:
  /// **'Named constants usable in any template. Reference them as vars.NAME. Values are literal — not re-interpolated. Useful for tokens, chat IDs, or anything reused across rules.'**
  String get hookEditVariablesHelper;

  /// No description provided for @hookEditAddVariable.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get hookEditAddVariable;

  /// No description provided for @hookEditSectionRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get hookEditSectionRules;

  /// No description provided for @hookEditRulesHelper.
  ///
  /// In en, this message translates to:
  /// **'The first rule whose \"when\" evaluates true fires. An empty \"when\" always matches.'**
  String get hookEditRulesHelper;

  /// No description provided for @hookEditAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get hookEditAddRule;

  /// No description provided for @hookEditShowPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview request'**
  String get hookEditShowPreview;

  /// No description provided for @hookEditHidePreview.
  ///
  /// In en, this message translates to:
  /// **'Hide preview'**
  String get hookEditHidePreview;

  /// No description provided for @hookEditPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No complete rules to preview yet.'**
  String get hookEditPreviewEmpty;

  /// No description provided for @hookEditPreviewRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule {n} — {when}'**
  String hookEditPreviewRuleTitle(int n, String when);

  /// No description provided for @hookEditPreviewMultipart.
  ///
  /// In en, this message translates to:
  /// **'(multipart: {count, plural, =1{1 part} other{{count} parts}})'**
  String hookEditPreviewMultipart(int count);

  /// No description provided for @hookEditErrNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get hookEditErrNameRequired;

  /// No description provided for @hookEditErrKeyFormat.
  ///
  /// In en, this message translates to:
  /// **'Key must be lowercase letters/digits/underscore'**
  String get hookEditErrKeyFormat;

  /// No description provided for @hookEditErrTriggers.
  ///
  /// In en, this message translates to:
  /// **'Select at least one trigger'**
  String get hookEditErrTriggers;

  /// No description provided for @hookEditErrRules.
  ///
  /// In en, this message translates to:
  /// **'Add at least one rule'**
  String get hookEditErrRules;

  /// No description provided for @hookEditErrRuleUrl.
  ///
  /// In en, this message translates to:
  /// **'Rule {n}: URL is required'**
  String hookEditErrRuleUrl(int n);

  /// No description provided for @hookEditErrRuleBuild.
  ///
  /// In en, this message translates to:
  /// **'Rule {n}: could not be built'**
  String hookEditErrRuleBuild(int n);

  /// No description provided for @hookEditErrVarNameFormat.
  ///
  /// In en, this message translates to:
  /// **'Variable {n}: name must start with a letter or underscore and contain only letters, digits, and underscores'**
  String hookEditErrVarNameFormat(int n);

  /// No description provided for @hookEditErrVarDup.
  ///
  /// In en, this message translates to:
  /// **'Variable {n}: name \"{name}\" is duplicated'**
  String hookEditErrVarDup(int n, String name);

  /// No description provided for @hookRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Rule {n}'**
  String hookRuleTitle(int n);

  /// No description provided for @hookRuleWhenLabel.
  ///
  /// In en, this message translates to:
  /// **'When (optional)'**
  String get hookRuleWhenLabel;

  /// No description provided for @hookRuleWhenHint.
  ///
  /// In en, this message translates to:
  /// **'post.files.length >= 2 && post.files.length <= 10'**
  String get hookRuleWhenHint;

  /// No description provided for @hookRuleWhenHelper.
  ///
  /// In en, this message translates to:
  /// **'First rule whose condition is true fires. Empty always matches.'**
  String get hookRuleWhenHelper;

  /// No description provided for @hookRuleMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get hookRuleMethodLabel;

  /// No description provided for @hookRuleUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL template'**
  String get hookRuleUrlLabel;

  /// No description provided for @hookRuleBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body template'**
  String get hookRuleBodyLabel;

  /// No description provided for @hookRuleBodyLabelDisabled.
  ///
  /// In en, this message translates to:
  /// **'Body template (disabled — multipart in use)'**
  String get hookRuleBodyLabelDisabled;

  /// No description provided for @hookRuleHeadersSection.
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get hookRuleHeadersSection;

  /// No description provided for @hookRuleHeaderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get hookRuleHeaderNameLabel;

  /// No description provided for @hookRuleHeaderValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get hookRuleHeaderValueLabel;

  /// No description provided for @hookRuleAddHeader.
  ///
  /// In en, this message translates to:
  /// **'Add header'**
  String get hookRuleAddHeader;

  /// No description provided for @hookRuleMultipartSection.
  ///
  /// In en, this message translates to:
  /// **'Multipart parts'**
  String get hookRuleMultipartSection;

  /// No description provided for @hookRuleAddPart.
  ///
  /// In en, this message translates to:
  /// **'Add part'**
  String get hookRuleAddPart;

  /// No description provided for @hookPartNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get hookPartNameLabel;

  /// No description provided for @hookPartNameHint.
  ///
  /// In en, this message translates to:
  /// **'chat_id, caption, photo, media…'**
  String get hookPartNameHint;

  /// No description provided for @hookPartKindText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get hookPartKindText;

  /// No description provided for @hookPartKindFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get hookPartKindFile;

  /// No description provided for @hookPartFilePathLabel.
  ///
  /// In en, this message translates to:
  /// **'File path (e.g. post.files.0.id or repeat.file.id)'**
  String get hookPartFilePathLabel;

  /// No description provided for @hookPartValueTemplateLabel.
  ///
  /// In en, this message translates to:
  /// **'Value template'**
  String get hookPartValueTemplateLabel;

  /// No description provided for @hookPartRepeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat over post.files'**
  String get hookPartRepeatLabel;

  /// No description provided for @hookPartJoinLabel.
  ///
  /// In en, this message translates to:
  /// **'Join (optional)'**
  String get hookPartJoinLabel;

  /// No description provided for @hookPartJoinHint.
  ///
  /// In en, this message translates to:
  /// **','**
  String get hookPartJoinHint;

  /// No description provided for @hookPartJoinHelper.
  ///
  /// In en, this message translates to:
  /// **'If set, iterations merge into one field'**
  String get hookPartJoinHelper;

  /// No description provided for @hookPartPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get hookPartPrefixLabel;

  /// No description provided for @hookPartSuffixLabel.
  ///
  /// In en, this message translates to:
  /// **'Suffix'**
  String get hookPartSuffixLabel;

  /// No description provided for @hookPartFilenameLabel.
  ///
  /// In en, this message translates to:
  /// **'Filename override (optional)'**
  String get hookPartFilenameLabel;

  /// No description provided for @hookPartRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get hookPartRemove;

  /// No description provided for @hookVarNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get hookVarNameLabel;

  /// No description provided for @hookVarNameHint.
  ///
  /// In en, this message translates to:
  /// **'bot_token'**
  String get hookVarNameHint;

  /// No description provided for @hookVarValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get hookVarValueLabel;

  /// No description provided for @hookVarRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove variable'**
  String get hookVarRemove;

  /// No description provided for @hookJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Hook JSON'**
  String get hookJsonTitle;

  /// No description provided for @hookJsonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get hookJsonCopy;

  /// No description provided for @hookJsonPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get hookJsonPaste;

  /// No description provided for @hookJsonFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get hookJsonFormat;

  /// No description provided for @hookJsonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get hookJsonApply;

  /// No description provided for @hookJsonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get hookJsonCopied;

  /// No description provided for @hookJsonHelper.
  ///
  /// In en, this message translates to:
  /// **'Edit this hook as JSON. Useful for pasting AI-generated hooks or moving a hook to another vault. The \"id\" field is internal — leave it alone, or omit it to generate a new one on Apply.'**
  String get hookJsonHelper;

  /// No description provided for @hookJsonErrParse.
  ///
  /// In en, this message translates to:
  /// **'Not valid JSON: {error}'**
  String hookJsonErrParse(String error);

  /// No description provided for @hookJsonErrTopLevel.
  ///
  /// In en, this message translates to:
  /// **'Top-level JSON value must be an object'**
  String get hookJsonErrTopLevel;

  /// No description provided for @hookJsonErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid hook JSON: {error}'**
  String hookJsonErrInvalid(String error);

  /// No description provided for @hookStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Hook status'**
  String get hookStatusTitle;

  /// No description provided for @hookStatusNone.
  ///
  /// In en, this message translates to:
  /// **'No hooks apply to this post.'**
  String get hookStatusNone;

  /// No description provided for @hookStatusApplicable.
  ///
  /// In en, this message translates to:
  /// **'Applicable ({count})'**
  String hookStatusApplicable(int count);

  /// No description provided for @hookStatusPast.
  ///
  /// In en, this message translates to:
  /// **'Past runs'**
  String get hookStatusPast;

  /// No description provided for @hookStatusRunAll.
  ///
  /// In en, this message translates to:
  /// **'Run all'**
  String get hookStatusRunAll;

  /// No description provided for @hookStatusRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get hookStatusRun;

  /// No description provided for @hookStatusHelper.
  ///
  /// In en, this message translates to:
  /// **'Hooks can be fired manually at any time. Templates referencing the trigger variable see the trigger from the hook\'s own settings.'**
  String get hookStatusHelper;

  /// No description provided for @hookStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get hookStatusRunning;

  /// No description provided for @hookStatusNeverFired.
  ///
  /// In en, this message translates to:
  /// **'Never fired'**
  String get hookStatusNeverFired;

  /// No description provided for @hookStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get hookStatusFailed;

  /// No description provided for @hookStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get hookStatusSuccess;

  /// No description provided for @hookStatusKey.
  ///
  /// In en, this message translates to:
  /// **'key: {key}'**
  String hookStatusKey(String key);

  /// No description provided for @hookStatusOrphan.
  ///
  /// In en, this message translates to:
  /// **'This hook no longer exists in the vault.'**
  String get hookStatusOrphan;

  /// No description provided for @hookStatusFired.
  ///
  /// In en, this message translates to:
  /// **'fired: {when}'**
  String hookStatusFired(String when);

  /// No description provided for @hookStatusError.
  ///
  /// In en, this message translates to:
  /// **'error: {message}'**
  String hookStatusError(String message);

  /// No description provided for @hookStatusStatus.
  ///
  /// In en, this message translates to:
  /// **'status: {code}'**
  String hookStatusStatus(String code);

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sync repositories configured.\n\nA repository backs up some or all of your spaces to GitHub or GitLab. Exactly one repository is marked primary and additionally backs up vault-level data (hooks).\n\nTap + to add one.'**
  String get syncEmpty;

  /// No description provided for @syncPushNow.
  ///
  /// In en, this message translates to:
  /// **'Push now'**
  String get syncPushNow;

  /// No description provided for @syncPullNow.
  ///
  /// In en, this message translates to:
  /// **'Pull now'**
  String get syncPullNow;

  /// No description provided for @syncMenuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit…'**
  String get syncMenuEdit;

  /// No description provided for @syncMenuSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as primary'**
  String get syncMenuSetPrimary;

  /// No description provided for @syncMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete…'**
  String get syncMenuDelete;

  /// No description provided for @syncAllSpaces.
  ///
  /// In en, this message translates to:
  /// **'All spaces'**
  String get syncAllSpaces;

  /// No description provided for @syncNoSpaces.
  ///
  /// In en, this message translates to:
  /// **'No spaces'**
  String get syncNoSpaces;

  /// No description provided for @syncSpacesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 space} other{{count} spaces}}'**
  String syncSpacesCount(int count);

  /// No description provided for @syncVaultDataSuffix.
  ///
  /// In en, this message translates to:
  /// **'+ vault data'**
  String get syncVaultDataSuffix;

  /// No description provided for @syncLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {when}'**
  String syncLastSynced(String when);

  /// No description provided for @syncPrimaryBadge.
  ///
  /// In en, this message translates to:
  /// **'PRIMARY'**
  String get syncPrimaryBadge;

  /// No description provided for @syncPrimaryNow.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is now the primary repository'**
  String syncPrimaryNow(String name);

  /// No description provided for @syncDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String syncDeleteTitle(String name);

  /// No description provided for @syncDeleteBodyPrimary.
  ///
  /// In en, this message translates to:
  /// **'This is the primary repository. Another will be automatically promoted to primary. The remote repository itself is not affected — only this app\'s configuration for it.'**
  String get syncDeleteBodyPrimary;

  /// No description provided for @syncDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The remote repository itself is not affected — only this app\'s configuration for it.'**
  String get syncDeleteBody;

  /// No description provided for @syncNoTokenSnack.
  ///
  /// In en, this message translates to:
  /// **'No token for \"{name}\". Open Edit to add one.'**
  String syncNoTokenSnack(String name);

  /// No description provided for @syncPushConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Push \"{name}\"?'**
  String syncPushConfirmTitle(String name);

  /// No description provided for @syncPushConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Uploads local changes to the remote. Unpulled remote changes will be overwritten.'**
  String get syncPushConfirmBody;

  /// No description provided for @syncPullConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull \"{name}\"?'**
  String syncPullConfirmTitle(String name);

  /// No description provided for @syncPullConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Overwrites local files in this config\'s scope with the remote version. A backup of the vault is saved first.'**
  String get syncPullConfirmBody;

  /// No description provided for @syncPushButton.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get syncPushButton;

  /// No description provided for @syncPullButton.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get syncPullButton;

  /// No description provided for @syncProgressStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get syncProgressStarting;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @syncDialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get syncDialogClose;

  /// No description provided for @syncDialogPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Push \"{name}\"'**
  String syncDialogPushTitle(String name);

  /// No description provided for @syncDialogPullTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull \"{name}\"'**
  String syncDialogPullTitle(String name);

  /// No description provided for @syncPushResultLine.
  ///
  /// In en, this message translates to:
  /// **'Pushed: {created} created, {updated} updated, {deleted} deleted'**
  String syncPushResultLine(int created, int updated, int deleted);

  /// No description provided for @syncPullResultLine.
  ///
  /// In en, this message translates to:
  /// **'Pulled: {added} added, {updated} updated, {deleted} deleted'**
  String syncPullResultLine(int added, int updated, int deleted);

  /// No description provided for @syncEditNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New repository'**
  String get syncEditNewTitle;

  /// No description provided for @syncEditExistingTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit repository'**
  String get syncEditExistingTitle;

  /// No description provided for @syncEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get syncEditSave;

  /// No description provided for @syncEditNameSection.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get syncEditNameSection;

  /// No description provided for @syncEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'My backup'**
  String get syncEditNameHint;

  /// No description provided for @syncEditNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Display name for this repository'**
  String get syncEditNameHelper;

  /// No description provided for @syncEditRemoteSection.
  ///
  /// In en, this message translates to:
  /// **'REMOTE'**
  String get syncEditRemoteSection;

  /// No description provided for @syncEditProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get syncEditProviderLabel;

  /// No description provided for @syncEditHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host (optional)'**
  String get syncEditHostLabel;

  /// No description provided for @syncEditHostHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for {defaultHost}. For self-hosted, enter the hostname.'**
  String syncEditHostHelper(String defaultHost);

  /// No description provided for @syncEditOwnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner / group'**
  String get syncEditOwnerLabel;

  /// No description provided for @syncEditRepoLabel.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get syncEditRepoLabel;

  /// No description provided for @syncEditBranchLabel.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get syncEditBranchLabel;

  /// No description provided for @syncEditPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'Path prefix (optional)'**
  String get syncEditPrefixLabel;

  /// No description provided for @syncEditPrimarySection.
  ///
  /// In en, this message translates to:
  /// **'PRIMARY'**
  String get syncEditPrimarySection;

  /// No description provided for @syncEditPrimarySwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Set as primary'**
  String get syncEditPrimarySwitchTitle;

  /// No description provided for @syncEditPrimarySubtitleOn.
  ///
  /// In en, this message translates to:
  /// **'This repo also backs up vault-level data (hooks).'**
  String get syncEditPrimarySubtitleOn;

  /// No description provided for @syncEditPrimarySubtitleOnly.
  ///
  /// In en, this message translates to:
  /// **'The only repository is automatically primary.'**
  String get syncEditPrimarySubtitleOnly;

  /// No description provided for @syncEditPrimarySubtitleOff.
  ///
  /// In en, this message translates to:
  /// **'Enabling this will demote the current primary.'**
  String get syncEditPrimarySubtitleOff;

  /// No description provided for @syncEditSpacesSection.
  ///
  /// In en, this message translates to:
  /// **'SPACES'**
  String get syncEditSpacesSection;

  /// No description provided for @syncEditSpacesAll.
  ///
  /// In en, this message translates to:
  /// **'All spaces (including future ones)'**
  String get syncEditSpacesAll;

  /// No description provided for @syncEditSpacesSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected spaces'**
  String get syncEditSpacesSelected;

  /// No description provided for @syncEditLoadRemote.
  ///
  /// In en, this message translates to:
  /// **'Load remote spaces'**
  String get syncEditLoadRemote;

  /// No description provided for @syncEditRemoteHintUnloaded.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Load remote spaces\" to see spaces that exist on the remote but haven\'t been pulled yet.'**
  String get syncEditRemoteHintUnloaded;

  /// No description provided for @syncEditRemoteHintLoaded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 space} other{{count} spaces}} on the remote. Remote-only spaces are marked.'**
  String syncEditRemoteHintLoaded(int count);

  /// No description provided for @syncEditRemoteOnlyBadge.
  ///
  /// In en, this message translates to:
  /// **'remote only'**
  String get syncEditRemoteOnlyBadge;

  /// No description provided for @syncEditRemoteOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not on this device yet — will be pulled on next sync'**
  String get syncEditRemoteOnlySubtitle;

  /// No description provided for @syncEditRemoteId.
  ///
  /// In en, this message translates to:
  /// **'id: {id}'**
  String syncEditRemoteId(String id);

  /// No description provided for @syncEditMissingRemote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 space exists on the remote but is not selected. It will not be pulled by this config until added.} other{{count} spaces exist on the remote but are not selected. They will not be pulled by this config until added.}}'**
  String syncEditMissingRemote(int count);

  /// No description provided for @syncEditDriveSection.
  ///
  /// In en, this message translates to:
  /// **'DRIVE OFFLOADING'**
  String get syncEditDriveSection;

  /// No description provided for @syncEditKeepLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep on disk (files per space)'**
  String get syncEditKeepLocalLabel;

  /// No description provided for @syncEditKeepLocalHelper.
  ///
  /// In en, this message translates to:
  /// **'Newest N files stay on disk; older files are offloaded to the remote and fetched on demand. Empty = keep everything.'**
  String get syncEditKeepLocalHelper;

  /// No description provided for @syncEditTokenSection.
  ///
  /// In en, this message translates to:
  /// **'TOKEN'**
  String get syncEditTokenSection;

  /// No description provided for @syncEditTokenStored.
  ///
  /// In en, this message translates to:
  /// **'Token stored'**
  String get syncEditTokenStored;

  /// No description provided for @syncEditTokenChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get syncEditTokenChange;

  /// No description provided for @syncEditTokenClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get syncEditTokenClear;

  /// No description provided for @syncEditTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal access token'**
  String get syncEditTokenLabel;

  /// No description provided for @syncEditTokenHelperGithub.
  ///
  /// In en, this message translates to:
  /// **'Create at github.com/settings/tokens with \"repo\" scope'**
  String get syncEditTokenHelperGithub;

  /// No description provided for @syncEditTokenHelperGitlab.
  ///
  /// In en, this message translates to:
  /// **'Create at gitlab.com/-/user_settings/personal_access_tokens with \"api\" scope'**
  String get syncEditTokenHelperGitlab;

  /// No description provided for @syncEditVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify access'**
  String get syncEditVerify;

  /// No description provided for @syncEditPushButton.
  ///
  /// In en, this message translates to:
  /// **'Push to remote'**
  String get syncEditPushButton;

  /// No description provided for @syncEditPullButton.
  ///
  /// In en, this message translates to:
  /// **'Pull from remote'**
  String get syncEditPullButton;

  /// No description provided for @syncEditReenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-enter token'**
  String get syncEditReenterTitle;

  /// No description provided for @syncEditReenterBody.
  ///
  /// In en, this message translates to:
  /// **'The provider, host, owner, or repo changed. Tokens are scoped to that combination, so the previously saved token can\'t be reused here.\n\nYou\'ll need to enter a new token. Save anyway without a token?'**
  String get syncEditReenterBody;

  /// No description provided for @syncEditSaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get syncEditSaveAnyway;

  /// No description provided for @syncEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get syncEditSaved;

  /// No description provided for @syncEditAccessVerified.
  ///
  /// In en, this message translates to:
  /// **'Access verified'**
  String get syncEditAccessVerified;

  /// No description provided for @syncEditTokenRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a token first'**
  String get syncEditTokenRequired;

  /// No description provided for @syncEditPushConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Push to remote?'**
  String get syncEditPushConfirmTitle;

  /// No description provided for @syncEditPushConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This uploads the selected spaces (and vault-level data if this is the primary) to the remote. Any changes on the remote that you haven\'t pulled will be overwritten.'**
  String get syncEditPushConfirmBody;

  /// No description provided for @syncEditPullConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull from remote?'**
  String get syncEditPullConfirmTitle;

  /// No description provided for @syncEditPullConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This overwrites local files in the selected spaces (and vault-level data if this is the primary) with the remote version. A backup of the vault is saved before pulling.\n\nOn web, the backup is stored in the browser\'s local storage and keeps only the 3 most recent backups.'**
  String get syncEditPullConfirmBody;

  /// No description provided for @syncEditRemoteLoadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out loading remote spaces. Tap \"Load remote spaces\" to retry.'**
  String get syncEditRemoteLoadTimedOut;

  /// No description provided for @syncEditRemoteLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load remote spaces: {error}'**
  String syncEditRemoteLoadFailed(String error);

  /// No description provided for @recallFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recall files'**
  String get recallFilesTitle;

  /// No description provided for @recallFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{space} · {count, plural, =1{1 file} other{{count} files}}'**
  String recallFilesSubtitle(String space, int count);

  /// No description provided for @recallFilesListTooltip.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get recallFilesListTooltip;

  /// No description provided for @recallFilesGridTooltip.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get recallFilesGridTooltip;

  /// No description provided for @recallFilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Drive is empty'**
  String get recallFilesEmpty;

  /// No description provided for @recallFilesNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'No files selected'**
  String get recallFilesNoneSelected;

  /// No description provided for @recallFilesSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String recallFilesSelectedCount(int count);

  /// No description provided for @recallFilesAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get recallFilesAttach;

  /// No description provided for @hookEditFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Unnamed hook'**
  String get hookEditFallbackName;

  /// No description provided for @hookEditFallbackKey.
  ///
  /// In en, this message translates to:
  /// **'unnamed'**
  String get hookEditFallbackKey;

  /// No description provided for @importFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Selected file is empty'**
  String get importFileEmpty;

  /// No description provided for @importFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read file: {error}'**
  String importFileReadFailed(String error);

  /// No description provided for @importFilesNoneReadable.
  ///
  /// In en, this message translates to:
  /// **'No readable files selected'**
  String get importFilesNoneReadable;

  /// No description provided for @importFilesReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read files: {error}'**
  String importFilesReadFailed(String error);

  /// No description provided for @settingsRichEditorSection.
  ///
  /// In en, this message translates to:
  /// **'EDITOR'**
  String get settingsRichEditorSection;

  /// No description provided for @settingsRichEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Rich text editor'**
  String get settingsRichEditorTitle;

  /// No description provided for @settingsRichEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Show formatting toolbar in the composer. When off, the composer uses plain text only.'**
  String get settingsRichEditorDescription;

  /// No description provided for @richEditorBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get richEditorBold;

  /// No description provided for @richEditorItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get richEditorItalic;

  /// No description provided for @richEditorUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get richEditorUnderline;

  /// No description provided for @richEditorStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get richEditorStrikethrough;

  /// No description provided for @richEditorInlineCode.
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get richEditorInlineCode;

  /// No description provided for @richEditorClearFormatting.
  ///
  /// In en, this message translates to:
  /// **'Clear formatting'**
  String get richEditorClearFormatting;

  /// No description provided for @composerRichFormattingLossWarning.
  ///
  /// In en, this message translates to:
  /// **'This content uses rich formatting. Editing here will remove bold, italic, underline, strikethrough, and inline code.'**
  String get composerRichFormattingLossWarning;

  /// No description provided for @feedCopySelected.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get feedCopySelected;

  /// No description provided for @feedCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Copied 1 post to clipboard} other{Copied {count} posts to clipboard}}'**
  String feedCopiedToClipboard(int count);

  /// No description provided for @feedGoToPost.
  ///
  /// In en, this message translates to:
  /// **'Open in feed'**
  String get feedGoToPost;

  /// No description provided for @feedCopySelectedWithDates.
  ///
  /// In en, this message translates to:
  /// **'Copy with dates'**
  String get feedCopySelectedWithDates;

  /// No description provided for @fileViewerCopyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy image'**
  String get fileViewerCopyImage;

  /// No description provided for @fileViewerCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Image copied to clipboard'**
  String get fileViewerCopiedToClipboard;

  /// No description provided for @fileViewerCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String fileViewerCopyFailed(String error);
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
