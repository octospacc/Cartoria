// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Cartoria';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonImport => 'Importa';

  @override
  String get commonCreate => 'Crea';

  @override
  String get commonClear => 'Svuota';

  @override
  String get commonReset => 'Reimposta';

  @override
  String get onboardingWelcome => 'Benvenuto';

  @override
  String get onboardingSkip => 'Salta';

  @override
  String get onboardingCreateFirstSpace => 'Crea il tuo primo spazio';

  @override
  String get onboardingBody =>
      'Uno spazio contiene le proprie note, segnalibri e file. Gli spazi sono indipendenti — puoi aggiungerne altri in seguito.';

  @override
  String get onboardingSpaceName => 'Nome dello spazio';

  @override
  String get onboardingCreateSpace => 'Crea spazio';

  @override
  String get spacesTitle => 'Spazi';

  @override
  String get spacesHooksTooltip => 'Hook';

  @override
  String get spacesSyncTooltip => 'Sincronizzazione';

  @override
  String get spacesImportTooltip => 'Nuovo spazio da file…';

  @override
  String get spacesSettingsTooltip => 'Impostazioni';

  @override
  String get spacesEmpty => 'Nessuno spazio';

  @override
  String get spacesEmptyHint =>
      'Tocca + per creare il tuo primo spazio, oppure importa da un file usando l\'icona in alto.';

  @override
  String get spacesEmptyLabel => 'Vuoto';

  @override
  String get spacesStatistics => 'Statistiche';

  @override
  String get spacesEdit => 'Modifica spazio…';

  @override
  String get spacesExport => 'Esporta spazio…';

  @override
  String get spacesDelete => 'Elimina spazio…';

  @override
  String spacesDeleteTitle(String name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get spacesDeleteBody =>
      'Rimuove ogni post e file di questo spazio. Impossibile annullare.';

  @override
  String spacesCountNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count note',
      one: '1 nota',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String spacesCountBookmarks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segnalibri',
      one: '1 segnalibro',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String spacesCountReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risposte',
      one: '1 risposta',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String spacesCountFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
      one: '1 file',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get spaceDialogNewTitle => 'Nuovo spazio';

  @override
  String get spaceDialogEditTitle => 'Modifica spazio';

  @override
  String get spaceDialogNameLabel => 'Nome';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsLanguageSection => 'LINGUA';

  @override
  String get settingsLanguageDescription =>
      'Lingua usata dall\'interfaccia. Viene usata anche per il controllo ortografico nel compositore.';

  @override
  String get settingsLanguageSystem => 'Predefinita di sistema';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageItalian => 'Italiano';

  @override
  String get settingsBackupsSection => 'BACKUP';

  @override
  String get settingsBackupsDescription =>
      'Un backup dell\'archivio viene creato prima di ogni pull, così un pull errato non può distruggere modifiche locali non ancora inviate. I backup più vecchi vengono eliminati automaticamente oltre il limite di conservazione.';

  @override
  String get settingsRetentionLabel => 'Conservazione (numero di backup)';

  @override
  String get settingsRetentionHelper =>
      'Lascia vuoto per usare il valore predefinito. Imposta a 0 per disattivare i backup pre-pull.';

  @override
  String get settingsRetentionSaveTooltip => 'Salva';

  @override
  String settingsRetentionCurrent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conservazione attuale: fino a $count backup',
      one: 'Conservazione attuale: fino a 1 backup',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupsLoading => 'Caricamento backup…';

  @override
  String settingsBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count backup',
      one: '1 backup',
      zero: 'Nessun backup',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupsEmpty =>
      'Ancora nessun backup. I backup vengono creati automaticamente prima di ogni pull.';

  @override
  String get settingsBackupsClearAll => 'Svuota tutto';

  @override
  String get settingsBackupsExportTooltip => 'Esporta';

  @override
  String get settingsBackupsDeleteTooltip => 'Elimina';

  @override
  String settingsBackupsClearTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Svuotare $count backup?',
      one: 'Svuotare 1 backup?',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupsClearBody =>
      'Elimina tutti i backup pre-pull. I dati attuali dell\'archivio non vengono toccati. Impossibile annullare.';

  @override
  String settingsBackupDeleteTitle(String name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get settingsBackupDeleteBody =>
      'Elimina questo backup. Gli altri backup e i dati attuali non vengono toccati.';

  @override
  String settingsRetentionSaved(int count) {
    return 'Conservazione impostata a $count';
  }

  @override
  String get settingsRetentionReset =>
      'Conservazione reimpostata al valore predefinito';

  @override
  String get settingsRetentionDisabled => 'Backup pre-pull disattivati';

  @override
  String get settingsRetentionInvalid =>
      'La conservazione deve essere un numero intero non negativo';

  @override
  String settingsSaveFailed(String error) {
    return 'Salvataggio non riuscito: $error';
  }

  @override
  String settingsListBackupsFailed(String error) {
    return 'Impossibile elencare i backup: $error';
  }

  @override
  String settingsExportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String settingsDeleteFailed(String error) {
    return 'Eliminazione non riuscita: $error';
  }

  @override
  String get spaceImportUnsupported => 'Tipo di file non supportato';

  @override
  String get spaceImportSinglePost =>
      'File di singolo post — apri uno spazio e usa Importa… lì';

  @override
  String get spaceImportNoBookmarks => 'Nessun segnalibro trovato';

  @override
  String get spaceImportDetails => 'Dettagli';

  @override
  String get spaceImportNothing => 'Niente importato';

  @override
  String spaceImportSummary(int ok, int failed, int cancelled) {
    return '$ok importati, $failed falliti, $cancelled annullati';
  }

  @override
  String spaceImportSummaryOkFailed(int ok, int failed) {
    return '$ok file importati · $failed falliti';
  }

  @override
  String spaceImportSummaryOk(int ok) {
    return '$ok file importati';
  }

  @override
  String spaceImportSummaryFailed(int failed) {
    return '$failed falliti';
  }

  @override
  String spaceImportSummaryCancelled(int cancelled) {
    return '$cancelled annullati';
  }

  @override
  String spaceImportZipResult(String name) {
    return 'Importato \"$name\"';
  }

  @override
  String spaceImportBookmarksResult(int count, String name) {
    return 'Importati $count in \"$name\"';
  }

  @override
  String get spaceImportBookmarksDialogTitle => 'Importa segnalibri';

  @override
  String get spaceImportDefaultBookmarksName => 'Segnalibri importati';

  @override
  String get feedSearchHint => 'Cerca in questo spazio…';

  @override
  String get feedSearchClear => 'Cancella';

  @override
  String get feedSearchClose => 'Chiudi ricerca';

  @override
  String feedSearchNoResults(String query) {
    return 'Nessun risultato per \"$query\"';
  }

  @override
  String feedSearchMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati',
      one: '1 risultato',
    );
    return '$_temp0';
  }

  @override
  String get feedEmpty => 'Ancora niente. Scrivi una nota o salva un link.';

  @override
  String get feedSelect => 'Seleziona';

  @override
  String get feedDrive => 'Drive';

  @override
  String get feedExitSelection => 'Esci dalla selezione';

  @override
  String feedSelectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String get feedSelectPosts => 'Seleziona post';

  @override
  String get feedDeleteSelected => 'Elimina selezionati';

  @override
  String feedDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare $count post?',
      one: 'Eliminare 1 post?',
    );
    return '$_temp0';
  }

  @override
  String get feedDeleteSelectedBody => 'Impossibile annullare.';

  @override
  String feedDeleteSelectedOrphaned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risposte diventeranno di primo livello.',
      one: '1 risposta diventerà di primo livello.',
    );
    return '$_temp0';
  }

  @override
  String get feedMenuImport => 'Importa…';

  @override
  String get feedMenuImportSource => 'Incolla sorgente post…';

  @override
  String feedImportOneFile(String name) {
    return 'Importato \"$name\"';
  }

  @override
  String get feedImportPost => 'Post importato';

  @override
  String get feedImportBookmarksFound => 'Nessun segnalibro trovato nel file';

  @override
  String feedImportFilesSummary(int ok) {
    return '$ok importati';
  }

  @override
  String feedImportErrorsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errori',
      one: '1 errore',
    );
    return '$_temp0';
  }

  @override
  String get feedUnsupportedFile => 'Tipo di file non supportato';

  @override
  String get feedPasteDialogTitle => 'Incolla sorgente post';

  @override
  String get feedPasteDialogHint =>
      'Incolla un file di post Cartoria — lo stesso formato di entries/<id>.html: un blocco frontmatter JSON <!--- … ---> seguito dal corpo HTML. Se manca, viene generato un nuovo ID.';

  @override
  String get composerNote => 'Nota';

  @override
  String get composerLink => 'Link';

  @override
  String get composerBodyHintNote => 'Scrivi qualcosa…';

  @override
  String get composerBodyHintBookmark => 'Perché salvare questo?';

  @override
  String get composerUrlHint => 'https://…';

  @override
  String get composerEmojiTooltip => 'Emoji';

  @override
  String get composerHooksSkip =>
      'Hook saltati per questo salvataggio — tocca per riattivare';

  @override
  String get composerHooksRun =>
      'Gli hook partiranno al salvataggio — tocca per saltare';

  @override
  String get composerExpand => 'Espandi a schermo intero';

  @override
  String get composerAttach => 'Allega';

  @override
  String get composerSend => 'Invia';

  @override
  String get composerDiscardDraft => 'Scarta bozza';

  @override
  String get composerSetDateTime => 'Imposta data/ora del post';

  @override
  String get composerNewPost => 'Nuovo post';

  @override
  String get composerReply => 'Rispondi';

  @override
  String get composerQuote => 'Cita';

  @override
  String get composerPost => 'Pubblica';

  @override
  String get composerEditing => 'Modifica post';

  @override
  String get composerQuoting => 'Citazione';

  @override
  String composerReplyingTo(String preview) {
    return 'In risposta a: $preview';
  }

  @override
  String composerQuotingPreview(String preview) {
    return 'Citando: $preview';
  }

  @override
  String get composerUrlLabel => 'URL';

  @override
  String get composerRefreshMetadata => 'Aggiorna metadati';

  @override
  String get composerTitleLabel => 'Titolo';

  @override
  String get composerDescriptionLabel => 'Descrizione';

  @override
  String get composerBodyLabel => 'Corpo';

  @override
  String get composerBodyHint => 'Scrivi il corpo…';

  @override
  String get composerPostedAt => 'Pubblicato il';

  @override
  String get composerPostedNow => 'Ora (predefinito)';

  @override
  String get composerSetTime => 'Imposta…';

  @override
  String get composerChangeTime => 'Cambia';

  @override
  String get composerResetTime => 'Reimposta a ora';

  @override
  String get composerHooksRunOnSave => 'Esegui hook al salvataggio';

  @override
  String get composerHooksWillSkip =>
      'Gli hook verranno saltati. Puoi attivarli dopo dal menu del post.';

  @override
  String composerHooksWillRun(String action) {
    return 'Gli hook corrispondenti partiranno quando tocchi $action.';
  }

  @override
  String get composerAddFile => 'Aggiungi file';

  @override
  String get composerUnsavedDraft => 'Bozza non salvata';

  @override
  String composerUnsavedDraftFrom(String when) {
    return 'Bozza non salvata da $when';
  }

  @override
  String get composerDraftReset => 'Reimposta';

  @override
  String get composerMetadataFetchFailed => 'Impossibile recuperare i metadati';

  @override
  String get composerUrlRequired => 'Inserisci prima un URL';

  @override
  String get composerBookmarkNeedsUrl => 'Un segnalibro richiede un URL';

  @override
  String get composerEscapeBack => 'Chiudi';

  @override
  String get composerRelativeJustNow => 'adesso';

  @override
  String composerRelativeMinutes(int count) {
    return '$count min fa';
  }

  @override
  String composerRelativeHours(int count) {
    return '$count h fa';
  }

  @override
  String composerRelativeDays(int count) {
    return '$count g fa';
  }

  @override
  String get composerFullScreenNoteTitle => 'Nota';

  @override
  String get composerFullScreenNoteHint => 'Scrivi qualcosa…';

  @override
  String get composerFullScreenBookmarkTitle => 'Perché salvare questo';

  @override
  String get composerFullScreenBookmarkHint => 'Perché salvare questo?';

  @override
  String get composerFullScreenEditTitle => 'Modifica corpo del post';

  @override
  String get composerFullScreenReplyTitle => 'Corpo della risposta';

  @override
  String get composerFullScreenQuoteTitle => 'Corpo della citazione';

  @override
  String get composerFullScreenNewTitle => 'Corpo del post';

  @override
  String get attachmentUpload => 'Carica nuovi file';

  @override
  String get attachmentPaste => 'Incolla dagli appunti';

  @override
  String get attachmentRecall => 'Richiama dal drive';

  @override
  String get attachmentPasteEmpty =>
      'Nessuna immagine o file negli appunti. Sul web, prova a premere Ctrl+V nel compositore.';

  @override
  String attachmentPasteFailed(String error) {
    return 'Incolla non riuscito: $error';
  }

  @override
  String attachmentUploadFailed(String error) {
    return 'Caricamento non riuscito: $error';
  }

  @override
  String attachmentUploadFailedCount(int count) {
    return '$count file non caricati';
  }

  @override
  String get attachmentDriveEmpty => 'Il drive è vuoto';

  @override
  String get postReply => 'Rispondi';

  @override
  String get postQuote => 'Cita';

  @override
  String get postEdit => 'Modifica';

  @override
  String get postSource => 'Mostra sorgente…';

  @override
  String get postHookStatus => 'Stato hook…';

  @override
  String get postDelete => 'Elimina';

  @override
  String postShowMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'risposte',
      one: 'risposta',
    );
    return 'Mostra altre $count $_temp0';
  }

  @override
  String postHideReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'risposte',
      one: 'risposta',
    );
    return 'Nascondi $count $_temp0';
  }

  @override
  String get postShowFewer => 'Mostra meno';

  @override
  String postRepliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'risposte',
      one: 'risposta',
    );
    return '$count $_temp0';
  }

  @override
  String get postDeleteNote => 'Eliminare questa nota?';

  @override
  String get postDeleteBookmark => 'Eliminare questo segnalibro?';

  @override
  String get postDeleteBody =>
      'I file allegati restano nel drive. Le risposte diventeranno di primo livello. Impossibile annullare.';

  @override
  String get postQuotedUnavailable => 'Post citato non disponibile';

  @override
  String get postQuotedFromSpace => 'Citato da questo spazio';

  @override
  String get postQuotedIncludesAnother => '↪ include un\'altra citazione';

  @override
  String get postQuotedExternal => 'Citazione esterna';

  @override
  String get postQuotedOpenHint => 'Tocca per aprire il post citato';

  @override
  String get postHookRunning => 'Hook in esecuzione…';

  @override
  String get postHookSuccess => 'Hook riusciti';

  @override
  String get postHookFailed => 'Hook falliti — tocca per i dettagli';

  @override
  String postEdited(String when) {
    return '· modificato $when';
  }

  @override
  String postShowQuotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citazioni',
      one: '1 citazione',
    );
    return '$_temp0';
  }

  @override
  String postHideQuotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citazioni',
      one: '1 citazione',
    );
    return 'Nascondi $_temp0';
  }

  @override
  String get postQuotedByHeader => 'CITATO DA';

  @override
  String get startupErrorTitle => 'Errore di avvio';

  @override
  String get startupErrorBody =>
      'Cartoria non è riuscita a completare l\'avvio. Di solito è un problema di permessi o di disco, non un bug dell\'app.';

  @override
  String get startupErrorStack => 'Stack:';

  @override
  String get driveTitle => 'Drive';

  @override
  String get driveMoreTooltip => 'Altro';

  @override
  String get driveOpen => 'Apri';

  @override
  String get driveUsageAction => 'Mostra i post che usano questo file…';

  @override
  String get driveShareAction => 'Condividi / scarica';

  @override
  String get driveDeleteAction => 'Elimina';

  @override
  String get driveSelectFiles => 'Seleziona file';

  @override
  String driveSelectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String get driveExitSelection => 'Esci dalla selezione';

  @override
  String get driveSelectUnused => 'Seleziona non usati';

  @override
  String get driveDeleteSelected => 'Elimina selezionati';

  @override
  String get driveSearchTooltip => 'Cerca';

  @override
  String get driveSearchClose => 'Chiudi ricerca';

  @override
  String get driveSearchHint => 'Cerca file…';

  @override
  String get driveClear => 'Cancella';

  @override
  String get driveGridTooltip => 'Vista griglia';

  @override
  String get driveListTooltip => 'Vista elenco';

  @override
  String get driveEmptyState =>
      'Ancora nessun file.\nCaricane uno qui, oppure allega da un post.';

  @override
  String driveNoMatch(String query) {
    return 'Nessun file corrisponde a \"$query\".';
  }

  @override
  String driveSummaryTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
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
    return '$count non usati';
  }

  @override
  String get driveUsageUsed => 'usato';

  @override
  String get driveUsageUnused => 'non usato';

  @override
  String get driveStatusMissing => 'mancante';

  @override
  String get driveStatusRemote => 'remoto';

  @override
  String driveDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
      one: '1 file',
    );
    return 'Eliminare $_temp0?';
  }

  @override
  String get driveDeleteSelectedBody =>
      'I post che fanno riferimento a questi file perderanno gli allegati. Impossibile annullare.';

  @override
  String driveDeleteFileTitle(String name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get driveDeleteFileBody =>
      'I post che fanno riferimento a questo file perderanno l\'allegato.';

  @override
  String driveMissingTitle(String name) {
    return '\"$name\" è mancante';
  }

  @override
  String get driveMissingBody =>
      'Questo file è referenziato da uno o più post, ma il suo contenuto non è memorizzato né su questo dispositivo né nel remoto di sincronizzazione.\n\nPuoi ripristinarlo reimportando l\'esportazione completa da cui proviene, scaricandolo dal remoto se lo possiede ancora, oppure scegliendo un file sostitutivo da questo dispositivo.';

  @override
  String get driveUploadReplacement => 'Carica sostituto…';

  @override
  String driveRestored(String name) {
    return 'Ripristinato \"$name\"';
  }

  @override
  String driveRestoreFailed(String error) {
    return 'Ripristino non riuscito: $error';
  }

  @override
  String driveUploadFailed(String error) {
    return 'Caricamento non riuscito: $error';
  }

  @override
  String driveUploadSummaryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file caricati',
      one: '1 file caricato',
    );
    return '$_temp0';
  }

  @override
  String driveUploadSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file non caricati',
      one: '1 file non caricato',
    );
    return '$_temp0';
  }

  @override
  String get driveUploadNothing => 'Nessun file caricato';

  @override
  String driveUploadDialogTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file non caricati',
      one: '1 file non caricato',
    );
    return '$_temp0';
  }

  @override
  String drivePastedFromClipboard(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
      one: '1 file',
    );
    return 'Aggiunti $_temp0 dagli appunti.';
  }

  @override
  String get drivePasteEmpty =>
      'Nessuna immagine o file negli appunti. Sul web, prova a incollare in un compositore.';

  @override
  String drivePasteFailed(String error) {
    return 'Incolla non riuscito: $error';
  }

  @override
  String get driveDownloadTitle => 'Scaricare dal remoto?';

  @override
  String driveDownloadBody(String name) {
    return '\"$name\" non è su questo dispositivo. Scaricarlo adesso?';
  }

  @override
  String get driveDownloadConfirm => 'Scarica';

  @override
  String driveDownloadFailed(String error) {
    return 'Download non riuscito: $error';
  }

  @override
  String linkPreviewOpenFailed(String url) {
    return 'Impossibile aprire $url';
  }

  @override
  String linkPreviewOpenError(String error) {
    return 'Impossibile aprire il link: $error';
  }

  @override
  String get postBodyImagePlaceholder => '[immagine]';

  @override
  String postBodyImagePlaceholderAlt(String alt) {
    return '[immagine: $alt]';
  }

  @override
  String get postBodyImageFailed => 'Impossibile caricare l\'immagine';

  @override
  String postBodyOpenFailed(String url) {
    return 'Impossibile aprire $url';
  }

  @override
  String postBodyOpenError(String error) {
    return 'Impossibile aprire il link: $error';
  }

  @override
  String get emojiTitle => 'Emoji';

  @override
  String get emojiCloseTooltip => 'Chiudi';

  @override
  String get fileUsageEmptyTitle => 'Non referenziato da alcun post';

  @override
  String fileUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count post fanno riferimento a questo file',
      one: '1 post fa riferimento a questo file',
    );
    return '$_temp0';
  }

  @override
  String get fileUsageNoPosts => 'Nessun post fa riferimento a questo file.';

  @override
  String get fileUsageNoText => '(senza testo)';

  @override
  String postSourceTitle(String shortId) {
    return 'Sorgente · $shortId…';
  }

  @override
  String get postSourceCopied => 'Sorgente copiata';

  @override
  String get postSourceCopy => 'Copia';

  @override
  String postSourceReadFailed(String error) {
    return 'Impossibile leggere la sorgente: $error';
  }

  @override
  String spaceActionsExportTitle(String name) {
    return 'Esporta \"$name\"';
  }

  @override
  String get spaceActionsFull => 'Completa';

  @override
  String spaceActionsFullBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sono $count e vengono scaricati',
      one: 'sono 1 e viene scaricato',
      zero: 'sono nessuno',
    );
    return 'Include ogni file. I file offloaded $_temp0 dal remoto di sincronizzazione prima di creare lo zip. Più lenta, ma l\'esportazione è autonoma.';
  }

  @override
  String get spaceActionsOnDisk => 'Solo su disco';

  @override
  String spaceActionsOnDiskBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file offloaded saltati.',
      one: '1 file offloaded saltato.',
      zero: 'Nessun file è offloaded.',
    );
    return 'Include i file attualmente memorizzati su questo dispositivo. $_temp0 I riferimenti ai file sono preservati nell\'esportazione; reimportando lo zip completo (o sincronizzando) in seguito si possono ripristinare i blob mancanti.';
  }

  @override
  String get spaceActionsNoMedia => 'Senza media';

  @override
  String get spaceActionsNoMediaBody =>
      'Nessun file. Solo il testo (note, segnalibri) e i riferimenti ai file. Esportazione più piccola; ogni file apparirà come mancante all\'importazione finché non viene ripristinato.';

  @override
  String spaceActionsExportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String spaceStatsCouldNotCompute(String error) {
    return 'Impossibile calcolare le statistiche: $error';
  }

  @override
  String get spaceStatsContent => 'Contenuto';

  @override
  String get spaceStatsTotal => 'Totale';

  @override
  String get spaceStatsNotes => 'Note';

  @override
  String get spaceStatsBookmarks => 'Segnalibri';

  @override
  String get spaceStatsReplies => 'Risposte (annidate)';

  @override
  String get spaceStatsDrive => 'Drive';

  @override
  String get spaceStatsFiles => 'File';

  @override
  String get spaceStatsStorage => 'Archiviazione';

  @override
  String get spaceStatsSpaceSize => 'Dimensione spazio';

  @override
  String get spaceStatsLocation => 'Percorso';

  @override
  String get fullScreenEditorEmojiTooltip => 'Emoji';

  @override
  String fullScreenEditorWordCount(int words, int chars) {
    String _temp0 = intl.Intl.pluralLogic(
      words,
      locale: localeName,
      other: '$words parole',
      one: '1 parola',
    );
    String _temp1 = intl.Intl.pluralLogic(
      chars,
      locale: localeName,
      other: '$chars caratteri',
      one: '1 carattere',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get bookmarkImportEmpty => 'Nessun segnalibro trovato nel file';

  @override
  String bookmarkImportAllPresent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segnalibri',
      one: '1 segnalibro',
    );
    return 'Tutti i $_temp0 sono già presenti';
  }

  @override
  String bookmarkImportAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segnalibri aggiunti',
      one: '1 segnalibro aggiunto',
    );
    return '$_temp0';
  }

  @override
  String bookmarkImportSkippedDup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicati saltati',
      one: '1 duplicato saltato',
    );
    return '$_temp0';
  }

  @override
  String bookmarkImportSkippedInvalid(int count) {
    return '$count invalidi saltati';
  }

  @override
  String get spaceZipImportEmpty => 'Nessun post trovato nello zip';

  @override
  String spaceZipImportAllPresent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return 'Tutti i $_temp0 sono già presenti';
  }

  @override
  String spaceZipImportImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi importati',
      one: '1 elemento importato',
    );
    return '$_temp0';
  }

  @override
  String spaceZipImportSkippedDup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicati saltati',
      one: '1 duplicato saltato',
    );
    return '$_temp0';
  }

  @override
  String spaceZipImportFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file importati',
      one: '1 file importato',
    );
    return '$_temp0';
  }

  @override
  String get fileViewerImageLoadFailed => 'Impossibile caricare l\'immagine';

  @override
  String get fileViewerRetry => 'Riprova';

  @override
  String fileViewerCannotPlayVideo(String error) {
    return 'Impossibile riprodurre il video: $error';
  }

  @override
  String fileViewerCannotPlayAudio(String error) {
    return 'Impossibile riprodurre l\'audio: $error';
  }

  @override
  String get fullScreenEditorDefaultTitle => 'Modifica';

  @override
  String get hooksTitle => 'Hook';

  @override
  String get hooksEmpty =>
      'Ancora nessun hook.\nUn hook esegue una richiesta HTTP quando un post viene creato o modificato.';

  @override
  String hooksDeleteTitle(String name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get hooksDeleteBody =>
      'I post mantengono i risultati dell\'ultima esecuzione, ma l\'hook non verrà più eseguito.';

  @override
  String hooksSummary(
      String rules, String triggers, String spaces, String key) {
    return '$rules · $triggers · $spaces · chiave: $key';
  }

  @override
  String hooksRulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regole',
      one: '1 regola',
    );
    return '$_temp0';
  }

  @override
  String get hooksSpacesAll => 'tutti gli spazi';

  @override
  String hooksSpacesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spazi',
      one: '1 spazio',
    );
    return '$_temp0';
  }

  @override
  String get hookTriggerCreate => 'crea';

  @override
  String get hookTriggerEdit => 'modifica';

  @override
  String get hookPreviewAlways => 'sempre';

  @override
  String get hookEditNew => 'Nuovo hook';

  @override
  String get hookEditExisting => 'Modifica hook';

  @override
  String get hookEditOpenJson => 'Modifica come JSON';

  @override
  String get hookEditSave => 'Salva';

  @override
  String get hookEditNameLabel => 'Nome';

  @override
  String get hookEditKeyLabel =>
      'Chiave (usata nei riferimenti a esecuzioni precedenti)';

  @override
  String get hookEditSectionTriggers => 'Eventi';

  @override
  String get hookEditOnCreate => 'Alla creazione';

  @override
  String get hookEditOnEdit => 'Alla modifica';

  @override
  String get hookEditSectionSpaces => 'Spazi';

  @override
  String get hookEditSectionPostKinds => 'Tipi di post';

  @override
  String get hookEditPostKindNote => 'Note';

  @override
  String get hookEditPostKindBookmark => 'Segnalibri';

  @override
  String get hookEditTagFilterLabel =>
      'Filtro tag (separati da virgola, opzionale)';

  @override
  String get hookEditTimeoutLabel => 'Timeout (secondi)';

  @override
  String get hookEditSectionVariables => 'Variabili';

  @override
  String get hookEditVariablesHelper =>
      'Costanti nominate utilizzabili in qualsiasi template. Riferiscile come vars.NOME. I valori sono letterali — non vengono re-interpolati. Utili per token, chat ID o qualsiasi cosa riutilizzata tra più regole.';

  @override
  String get hookEditAddVariable => 'Aggiungi variabile';

  @override
  String get hookEditSectionRules => 'Regole';

  @override
  String get hookEditRulesHelper =>
      'Si attiva la prima regola la cui condizione \"when\" risulta vera. Una \"when\" vuota corrisponde sempre.';

  @override
  String get hookEditAddRule => 'Aggiungi regola';

  @override
  String get hookEditShowPreview => 'Anteprima richiesta';

  @override
  String get hookEditHidePreview => 'Nascondi anteprima';

  @override
  String get hookEditPreviewEmpty =>
      'Nessuna regola completa da mostrare in anteprima.';

  @override
  String hookEditPreviewRuleTitle(int n, String when) {
    return 'Regola $n — $when';
  }

  @override
  String hookEditPreviewMultipart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parti',
      one: '1 parte',
    );
    return '(multipart: $_temp0)';
  }

  @override
  String get hookEditErrNameRequired => 'Il nome è obbligatorio';

  @override
  String get hookEditErrKeyFormat =>
      'La chiave deve contenere solo lettere minuscole, cifre e underscore';

  @override
  String get hookEditErrTriggers => 'Seleziona almeno un evento';

  @override
  String get hookEditErrRules => 'Aggiungi almeno una regola';

  @override
  String hookEditErrRuleUrl(int n) {
    return 'Regola $n: l\'URL è obbligatorio';
  }

  @override
  String hookEditErrRuleBuild(int n) {
    return 'Regola $n: impossibile costruire la regola';
  }

  @override
  String hookEditErrVarNameFormat(int n) {
    return 'Variabile $n: il nome deve iniziare con una lettera o underscore e contenere solo lettere, cifre e underscore';
  }

  @override
  String hookEditErrVarDup(int n, String name) {
    return 'Variabile $n: il nome \"$name\" è duplicato';
  }

  @override
  String hookRuleTitle(int n) {
    return 'Regola $n';
  }

  @override
  String get hookRuleWhenLabel => 'Quando (opzionale)';

  @override
  String get hookRuleWhenHint =>
      'post.files.length >= 2 && post.files.length <= 10';

  @override
  String get hookRuleWhenHelper =>
      'Si attiva la prima regola la cui condizione risulta vera. Vuota corrisponde sempre.';

  @override
  String get hookRuleMethodLabel => 'Metodo';

  @override
  String get hookRuleUrlLabel => 'URL template';

  @override
  String get hookRuleBodyLabel => 'Template del corpo';

  @override
  String get hookRuleBodyLabelDisabled =>
      'Template del corpo (disattivato — multipart in uso)';

  @override
  String get hookRuleHeadersSection => 'Intestazioni';

  @override
  String get hookRuleHeaderNameLabel => 'Nome';

  @override
  String get hookRuleHeaderValueLabel => 'Valore';

  @override
  String get hookRuleAddHeader => 'Aggiungi intestazione';

  @override
  String get hookRuleMultipartSection => 'Parti multipart';

  @override
  String get hookRuleAddPart => 'Aggiungi parte';

  @override
  String get hookPartNameLabel => 'Nome';

  @override
  String get hookPartNameHint => 'chat_id, caption, photo, media…';

  @override
  String get hookPartKindText => 'Testo';

  @override
  String get hookPartKindFile => 'File';

  @override
  String get hookPartFilePathLabel =>
      'Percorso file (es. post.files.0.id o repeat.file.id)';

  @override
  String get hookPartValueTemplateLabel => 'Template del valore';

  @override
  String get hookPartRepeatLabel => 'Ripeti su post.files';

  @override
  String get hookPartJoinLabel => 'Unisci (opzionale)';

  @override
  String get hookPartJoinHint => ',';

  @override
  String get hookPartJoinHelper =>
      'Se impostato, le iterazioni vengono unite in un unico campo';

  @override
  String get hookPartPrefixLabel => 'Prefisso';

  @override
  String get hookPartSuffixLabel => 'Suffisso';

  @override
  String get hookPartFilenameLabel => 'Nome file alternativo (opzionale)';

  @override
  String get hookPartRemove => 'Rimuovi';

  @override
  String get hookVarNameLabel => 'Nome';

  @override
  String get hookVarNameHint => 'bot_token';

  @override
  String get hookVarValueLabel => 'Valore';

  @override
  String get hookVarRemove => 'Rimuovi variabile';

  @override
  String get hookJsonTitle => 'JSON dell\'hook';

  @override
  String get hookJsonCopy => 'Copia';

  @override
  String get hookJsonPaste => 'Incolla';

  @override
  String get hookJsonFormat => 'Formatta';

  @override
  String get hookJsonApply => 'Applica';

  @override
  String get hookJsonCopied => 'Copiato negli appunti';

  @override
  String get hookJsonHelper =>
      'Modifica questo hook come JSON. Utile per incollare hook generati dall\'AI o spostare un hook in un altro archivio. Il campo \"id\" è interno — lascialo com\'è, oppure omettilo per generarne uno nuovo all\'Applica.';

  @override
  String hookJsonErrParse(String error) {
    return 'JSON non valido: $error';
  }

  @override
  String get hookJsonErrTopLevel =>
      'Il valore JSON di livello superiore deve essere un oggetto';

  @override
  String hookJsonErrInvalid(String error) {
    return 'JSON dell\'hook non valido: $error';
  }

  @override
  String get hookStatusTitle => 'Stato degli hook';

  @override
  String get hookStatusNone => 'Nessun hook si applica a questo post.';

  @override
  String hookStatusApplicable(int count) {
    return 'Applicabili ($count)';
  }

  @override
  String get hookStatusPast => 'Esecuzioni precedenti';

  @override
  String get hookStatusRunAll => 'Esegui tutti';

  @override
  String get hookStatusRun => 'Esegui';

  @override
  String get hookStatusHelper =>
      'Gli hook possono essere eseguiti manualmente in qualsiasi momento. I template che fanno riferimento alla variabile trigger vedono il trigger dalle impostazioni dell\'hook stesso.';

  @override
  String get hookStatusRunning => 'In esecuzione';

  @override
  String get hookStatusNeverFired => 'Mai eseguito';

  @override
  String get hookStatusFailed => 'Fallito';

  @override
  String get hookStatusSuccess => 'Riuscito';

  @override
  String hookStatusKey(String key) {
    return 'chiave: $key';
  }

  @override
  String get hookStatusOrphan => 'Questo hook non esiste più nell\'archivio.';

  @override
  String hookStatusFired(String when) {
    return 'eseguito: $when';
  }

  @override
  String hookStatusError(String message) {
    return 'errore: $message';
  }

  @override
  String hookStatusStatus(String code) {
    return 'stato: $code';
  }

  @override
  String get syncTitle => 'Sincronizzazione';

  @override
  String get syncEmpty =>
      'Nessun repository di sincronizzazione configurato.\n\nUn repository esegue il backup di alcuni o tutti i tuoi spazi su GitHub o GitLab. Esattamente un repository è marcato come primario e in più esegue il backup dei dati a livello di archivio (hook).\n\nTocca + per aggiungerne uno.';

  @override
  String get syncPushNow => 'Carica ora';

  @override
  String get syncPullNow => 'Scarica ora';

  @override
  String get syncMenuEdit => 'Modifica…';

  @override
  String get syncMenuSetPrimary => 'Imposta come primario';

  @override
  String get syncMenuDelete => 'Elimina…';

  @override
  String get syncAllSpaces => 'Tutti gli spazi';

  @override
  String get syncNoSpaces => 'Nessuno spazio';

  @override
  String syncSpacesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spazi',
      one: '1 spazio',
    );
    return '$_temp0';
  }

  @override
  String get syncVaultDataSuffix => '+ dati archivio';

  @override
  String syncLastSynced(String when) {
    return 'Ultima sincronizzazione: $when';
  }

  @override
  String get syncPrimaryBadge => 'PRIMARIO';

  @override
  String syncPrimaryNow(String name) {
    return '\"$name\" è ora il repository primario';
  }

  @override
  String syncDeleteTitle(String name) {
    return 'Eliminare \"$name\"?';
  }

  @override
  String get syncDeleteBodyPrimary =>
      'Questo è il repository primario. Un altro verrà automaticamente promosso a primario. Il repository remoto in sé non viene toccato — solo la configurazione di questa app per esso.';

  @override
  String get syncDeleteBody =>
      'Il repository remoto in sé non viene toccato — solo la configurazione di questa app per esso.';

  @override
  String syncNoTokenSnack(String name) {
    return 'Nessun token per \"$name\". Apri Modifica per aggiungerne uno.';
  }

  @override
  String syncPushConfirmTitle(String name) {
    return 'Caricare \"$name\"?';
  }

  @override
  String get syncPushConfirmBody =>
      'Carica le modifiche locali sul remoto. Le modifiche remote non ancora scaricate verranno sovrascritte.';

  @override
  String syncPullConfirmTitle(String name) {
    return 'Scaricare \"$name\"?';
  }

  @override
  String get syncPullConfirmBody =>
      'Sovrascrive i file locali nell\'ambito di questa configurazione con la versione remota. Prima viene salvato un backup dell\'archivio.';

  @override
  String get syncPushButton => 'Carica';

  @override
  String get syncPullButton => 'Scarica';

  @override
  String get syncProgressStarting => 'Avvio…';

  @override
  String get syncFailed => 'Sincronizzazione non riuscita';

  @override
  String get syncComplete => 'Sincronizzazione completata';

  @override
  String get syncDialogClose => 'Chiudi';

  @override
  String syncDialogPushTitle(String name) {
    return 'Carica \"$name\"';
  }

  @override
  String syncDialogPullTitle(String name) {
    return 'Scarica \"$name\"';
  }

  @override
  String syncPushResultLine(int created, int updated, int deleted) {
    return 'Caricati: $created creati, $updated aggiornati, $deleted eliminati';
  }

  @override
  String syncPullResultLine(int added, int updated, int deleted) {
    return 'Scaricati: $added aggiunti, $updated aggiornati, $deleted eliminati';
  }

  @override
  String get syncEditNewTitle => 'Nuovo repository';

  @override
  String get syncEditExistingTitle => 'Modifica repository';

  @override
  String get syncEditSave => 'Salva';

  @override
  String get syncEditNameSection => 'NOME';

  @override
  String get syncEditNameHint => 'Il mio backup';

  @override
  String get syncEditNameHelper => 'Nome visualizzato per questo repository';

  @override
  String get syncEditRemoteSection => 'REMOTO';

  @override
  String get syncEditProviderLabel => 'Provider';

  @override
  String get syncEditHostLabel => 'Host (opzionale)';

  @override
  String syncEditHostHelper(String defaultHost) {
    return 'Lascia vuoto per $defaultHost. Per installazioni self-hosted, inserisci il nome host.';
  }

  @override
  String get syncEditOwnerLabel => 'Proprietario / gruppo';

  @override
  String get syncEditRepoLabel => 'Repository';

  @override
  String get syncEditBranchLabel => 'Branch';

  @override
  String get syncEditPrefixLabel => 'Prefisso percorso (opzionale)';

  @override
  String get syncEditPrimarySection => 'PRIMARIO';

  @override
  String get syncEditPrimarySwitchTitle => 'Imposta come primario';

  @override
  String get syncEditPrimarySubtitleOn =>
      'Questo repo esegue anche il backup dei dati a livello di archivio (hook).';

  @override
  String get syncEditPrimarySubtitleOnly =>
      'L\'unico repository è automaticamente primario.';

  @override
  String get syncEditPrimarySubtitleOff =>
      'Attivandolo, il primario attuale verrà declassato.';

  @override
  String get syncEditSpacesSection => 'SPAZI';

  @override
  String get syncEditSpacesAll => 'Tutti gli spazi (inclusi quelli futuri)';

  @override
  String get syncEditSpacesSelected => 'Spazi selezionati';

  @override
  String get syncEditLoadRemote => 'Carica spazi remoti';

  @override
  String get syncEditRemoteHintUnloaded =>
      'Tocca \"Carica spazi remoti\" per vedere gli spazi esistenti sul remoto ma non ancora scaricati.';

  @override
  String syncEditRemoteHintLoaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spazi',
      one: '1 spazio',
    );
    return '$_temp0 sul remoto. Gli spazi solo-remoti sono contrassegnati.';
  }

  @override
  String get syncEditRemoteOnlyBadge => 'solo remoto';

  @override
  String get syncEditRemoteOnlySubtitle =>
      'Non ancora su questo dispositivo — verrà scaricato alla prossima sincronizzazione';

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
          '$count spazi esistono sul remoto ma non sono selezionati. Non verranno scaricati da questa configurazione finché non vengono aggiunti.',
      one:
          '1 spazio esiste sul remoto ma non è selezionato. Non verrà scaricato da questa configurazione finché non viene aggiunto.',
    );
    return '$_temp0';
  }

  @override
  String get syncEditDriveSection => 'OFFLOADING DRIVE';

  @override
  String get syncEditKeepLocalLabel => 'Mantieni su disco (file per spazio)';

  @override
  String get syncEditKeepLocalHelper =>
      'Gli N file più recenti restano su disco; i file più vecchi vengono offloaded al remoto e scaricati on demand. Vuoto = mantieni tutto.';

  @override
  String get syncEditTokenSection => 'TOKEN';

  @override
  String get syncEditTokenStored => 'Token memorizzato';

  @override
  String get syncEditTokenChange => 'Cambia';

  @override
  String get syncEditTokenClear => 'Cancella';

  @override
  String get syncEditTokenLabel => 'Token di accesso personale';

  @override
  String get syncEditTokenHelperGithub =>
      'Crealo su github.com/settings/tokens con scope \"repo\"';

  @override
  String get syncEditTokenHelperGitlab =>
      'Crealo su gitlab.com/-/user_settings/personal_access_tokens con scope \"api\"';

  @override
  String get syncEditVerify => 'Verifica accesso';

  @override
  String get syncEditPushButton => 'Carica sul remoto';

  @override
  String get syncEditPullButton => 'Scarica dal remoto';

  @override
  String get syncEditReenterTitle => 'Reinserisci token';

  @override
  String get syncEditReenterBody =>
      'Provider, host, proprietario o repo sono cambiati. I token sono limitati a quella combinazione, quindi il token salvato in precedenza non può essere riutilizzato qui.\n\nDovrai inserire un nuovo token. Salvare comunque senza un token?';

  @override
  String get syncEditSaveAnyway => 'Salva comunque';

  @override
  String get syncEditSaved => 'Salvato';

  @override
  String get syncEditAccessVerified => 'Accesso verificato';

  @override
  String get syncEditTokenRequired => 'Inserisci prima un token';

  @override
  String get syncEditPushConfirmTitle => 'Caricare sul remoto?';

  @override
  String get syncEditPushConfirmBody =>
      'Carica gli spazi selezionati (e i dati a livello di archivio se questo è il primario) sul remoto. Le modifiche sul remoto che non hai scaricato verranno sovrascritte.';

  @override
  String get syncEditPullConfirmTitle => 'Scaricare dal remoto?';

  @override
  String get syncEditPullConfirmBody =>
      'Sovrascrive i file locali negli spazi selezionati (e i dati a livello di archivio se questo è il primario) con la versione remota. Prima di scaricare viene salvato un backup dell\'archivio.\n\nSul web, il backup è memorizzato nel local storage del browser e mantiene solo i 3 backup più recenti.';

  @override
  String get syncEditRemoteLoadTimedOut =>
      'Timeout durante il caricamento degli spazi remoti. Tocca \"Carica spazi remoti\" per riprovare.';

  @override
  String syncEditRemoteLoadFailed(String error) {
    return 'Impossibile caricare gli spazi remoti: $error';
  }

  @override
  String get recallFilesTitle => 'Richiama file';

  @override
  String recallFilesSubtitle(String space, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file',
      one: '1 file',
    );
    return '$space · $_temp0';
  }

  @override
  String get recallFilesListTooltip => 'Vista elenco';

  @override
  String get recallFilesGridTooltip => 'Vista griglia';

  @override
  String get recallFilesEmpty => 'Il drive è vuoto';

  @override
  String get recallFilesNoneSelected => 'Nessun file selezionato';

  @override
  String recallFilesSelectedCount(int count) {
    return '$count selezionati';
  }

  @override
  String get recallFilesAttach => 'Allega';

  @override
  String get hookEditFallbackName => 'Hook senza nome';

  @override
  String get hookEditFallbackKey => 'senza_nome';

  @override
  String get importFileEmpty => 'Il file selezionato è vuoto';

  @override
  String importFileReadFailed(String error) {
    return 'Impossibile leggere il file: $error';
  }

  @override
  String get importFilesNoneReadable => 'Nessun file leggibile selezionato';

  @override
  String importFilesReadFailed(String error) {
    return 'Impossibile leggere i file: $error';
  }

  @override
  String get settingsRichEditorSection => 'EDITOR';

  @override
  String get settingsRichEditorTitle => 'Editor di testo formattato';

  @override
  String get settingsRichEditorDescription =>
      'Mostra la barra di formattazione nel compositore. Se disattivato, il compositore usa solo testo semplice.';

  @override
  String get richEditorBold => 'Grassetto';

  @override
  String get richEditorItalic => 'Corsivo';

  @override
  String get richEditorUnderline => 'Sottolineato';

  @override
  String get richEditorStrikethrough => 'Barrato';

  @override
  String get richEditorInlineCode => 'Codice in linea';

  @override
  String get richEditorClearFormatting => 'Rimuovi formattazione';

  @override
  String get composerRichFormattingLossWarning =>
      'Questo contenuto usa formattazione avanzata. Modificarlo qui rimuoverà grassetto, corsivo, sottolineato, barrato e codice in linea.';

  @override
  String get feedCopySelected => 'Copia';

  @override
  String feedCopiedToClipboard(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Copiati $count post negli appunti',
      one: 'Copiato 1 post negli appunti',
    );
    return '$_temp0';
  }

  @override
  String get feedGoToPost => 'Apri nel feed';

  @override
  String get feedCopySelectedWithDates => 'Copia con date';

  @override
  String get fileViewerCopyImage => 'Copia immagine';

  @override
  String get fileViewerCopiedToClipboard => 'Immagine copiata negli appunti';

  @override
  String fileViewerCopyFailed(String error) {
    return 'Copia non riuscita: $error';
  }

  @override
  String get feedExpandThread => 'Espandi thread';

  @override
  String get feedCollapseThread => 'Comprimi thread';

  @override
  String get composerPostIn => 'Pubblica in';

  @override
  String get searchDateRange => 'Intervallo di date';

  @override
  String get searchClearDateRange => 'Rimuovi filtro date';

  @override
  String searchDateRangeLabel(String from, String to) {
    return '$from – $to';
  }
}
