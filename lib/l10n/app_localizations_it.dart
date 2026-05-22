// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appSubtitle => 'Editor di documenti';

  @override
  String get open => 'Apri';

  @override
  String get openDocument => 'Apri documento';

  @override
  String get noRecentDocuments => 'Nessun documento recente';

  @override
  String get emptyStateSubtitle =>
      'Apri un file .odt esistente o crea\nun nuovo documento per iniziare.';

  @override
  String get recentSectionTitle => 'Recenti';

  @override
  String get newDocument => 'Nuovo documento';

  @override
  String get loadingOpeningDocument => 'Apertura documento…';

  @override
  String get unsavedDraft => 'Bozza non salvata';

  @override
  String tapToResume(String name) {
    return 'Tocca per riprendere $name';
  }

  @override
  String get discardDraft => 'Scarta bozza';

  @override
  String get documentFallbackName => 'documento';

  @override
  String get dateToday => 'Oggi';

  @override
  String get dateYesterday => 'Ieri';

  @override
  String dateDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String get errorCannotReadFile => 'Impossibile leggere il file.';

  @override
  String errorUnsupportedFormat(String ext) {
    return 'Formato non supportato: .$ext';
  }

  @override
  String get errorUnexpectedOpening => 'Errore imprevisto durante l\'apertura.';

  @override
  String errorCacheUnavailable(String name) {
    return 'Cache non più disponibile per \"$name\". Aprilo manualmente.';
  }

  @override
  String get untitledDocument => 'Documento senza titolo';

  @override
  String get editorPlaceholder => 'Inizia a scrivere…';

  @override
  String get draftSaved => 'Bozza salvata';

  @override
  String get save => 'Salva';

  @override
  String get saveAs => 'Salva con nome';

  @override
  String get more => 'Altro';

  @override
  String get exportAsMarkdown => 'Esporta come Markdown (.md)';

  @override
  String get exportAsText => 'Esporta come testuale (.txt)';

  @override
  String get saved => 'Salvato';

  @override
  String savedAs(String fileName) {
    return 'Salvato: $fileName';
  }

  @override
  String exported(String fileName) {
    return 'Esportato: $fileName';
  }

  @override
  String errorSaving(String error) {
    return 'Errore nel salvataggio: $error';
  }

  @override
  String errorExporting(String error) {
    return 'Errore nell\'esportazione: $error';
  }

  @override
  String exportDialogTitle(String format) {
    return 'Esporta come $format';
  }

  @override
  String get fileNameLabel => 'Nome file';

  @override
  String get folderLabel => 'Cartella';

  @override
  String get change => 'Cambia';

  @override
  String get cancel => 'Annulla';

  @override
  String get chooseFolderDialogTitle => 'Scegli cartella di salvataggio';

  @override
  String get odfErrorInvalidArchive =>
      'Il file non sembra essere un documento .odt valido.';

  @override
  String get odfErrorMissingContent =>
      'Il documento è incompleto: manca content.xml.';

  @override
  String get odfErrorMalformedXml =>
      'Il contenuto del documento è danneggiato.';

  @override
  String get odfErrorUnknown =>
      'Errore imprevisto durante l\'elaborazione del documento.';

  @override
  String get conversionErrorNotValidUtf8 => 'Il file non è testo UTF-8 valido.';

  @override
  String get conversionErrorMarkdownFailed =>
      'Impossibile convertire il Markdown.';

  @override
  String get conversionErrorOdfNotPlainText =>
      'Il file sembra un documento ODF, non un testo normale. Rinominalo in .odt e aprilo con \"Apri\".';
}
