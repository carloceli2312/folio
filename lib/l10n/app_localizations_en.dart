// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appSubtitle => 'Document editor';

  @override
  String get open => 'Open';

  @override
  String get openDocument => 'Open document';

  @override
  String get noRecentDocuments => 'No recent documents';

  @override
  String get emptyStateSubtitle =>
      'Open an existing .odt file or create\na new document to get started.';

  @override
  String get recentSectionTitle => 'Recent';

  @override
  String get newDocument => 'New document';

  @override
  String get loadingOpeningDocument => 'Opening document…';

  @override
  String get unsavedDraft => 'Unsaved draft';

  @override
  String tapToResume(String name) {
    return 'Tap to resume $name';
  }

  @override
  String get discardDraft => 'Discard draft';

  @override
  String get documentFallbackName => 'document';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String dateDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get errorCannotReadFile => 'Unable to read the file.';

  @override
  String errorUnsupportedFormat(String ext) {
    return 'Unsupported format: .$ext';
  }

  @override
  String get errorUnexpectedOpening =>
      'An unexpected error occurred while opening the document.';

  @override
  String errorCacheUnavailable(String name) {
    return 'Cache no longer available for \"$name\". Open it manually.';
  }

  @override
  String get untitledDocument => 'Untitled document';

  @override
  String get editorPlaceholder => 'Start writing…';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save as';

  @override
  String get more => 'More';

  @override
  String get exportAsMarkdown => 'Export as Markdown (.md)';

  @override
  String get exportAsText => 'Export as plain text (.txt)';

  @override
  String get saved => 'Saved';

  @override
  String savedAs(String fileName) {
    return 'Saved: $fileName';
  }

  @override
  String exported(String fileName) {
    return 'Exported: $fileName';
  }

  @override
  String errorSaving(String error) {
    return 'Error while saving: $error';
  }

  @override
  String errorExporting(String error) {
    return 'Error while exporting: $error';
  }

  @override
  String exportDialogTitle(String format) {
    return 'Export as $format';
  }

  @override
  String get fileNameLabel => 'File name';

  @override
  String get folderLabel => 'Folder';

  @override
  String get change => 'Change';

  @override
  String get cancel => 'Cancel';

  @override
  String get chooseFolderDialogTitle => 'Choose save folder';

  @override
  String get odfErrorInvalidArchive =>
      'This file does not look like a valid .odt document.';

  @override
  String get odfErrorMissingContent =>
      'The document is incomplete: content.xml is missing.';

  @override
  String get odfErrorMalformedXml => 'The document content is corrupted.';

  @override
  String get odfErrorUnknown =>
      'An unexpected error occurred while processing the document.';

  @override
  String get conversionErrorNotValidUtf8 => 'The file is not valid UTF-8 text.';

  @override
  String get conversionErrorMarkdownFailed =>
      'The Markdown file could not be converted.';

  @override
  String get conversionErrorOdfNotPlainText =>
      'This file looks like an ODF document, not plain text. Rename it to .odt and open it with \"Open\".';
}
