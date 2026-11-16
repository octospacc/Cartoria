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
}
