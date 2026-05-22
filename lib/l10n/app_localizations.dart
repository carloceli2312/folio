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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('it'),
  ];

  /// Subtitle shown under the app name on the home header
  ///
  /// In en, this message translates to:
  /// **'Document editor'**
  String get appSubtitle;

  /// Label of the Open button in the home header
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Label of the button in the empty state that opens the file picker
  ///
  /// In en, this message translates to:
  /// **'Open document'**
  String get openDocument;

  /// Empty state title shown when there are no recent files or drafts
  ///
  /// In en, this message translates to:
  /// **'No recent documents'**
  String get noRecentDocuments;

  /// Empty state subtitle inviting the user to open or create a document
  ///
  /// In en, this message translates to:
  /// **'Open an existing .odt file or create\na new document to get started.'**
  String get emptyStateSubtitle;

  /// Section header above the list of recently opened documents
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentSectionTitle;

  /// Tooltip of the new-document button and default name for a new document
  ///
  /// In en, this message translates to:
  /// **'New document'**
  String get newDocument;

  /// Message shown in the loading overlay while a document is being parsed
  ///
  /// In en, this message translates to:
  /// **'Opening document…'**
  String get loadingOpeningDocument;

  /// Title of the banner offering to resume an unsaved draft
  ///
  /// In en, this message translates to:
  /// **'Unsaved draft'**
  String get unsavedDraft;

  /// Draft banner subtitle inviting the user to resume editing a draft
  ///
  /// In en, this message translates to:
  /// **'Tap to resume {name}'**
  String tapToResume(String name);

  /// Tooltip of the button that discards an unsaved draft
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get discardDraft;

  /// Generic noun used when a document has no name
  ///
  /// In en, this message translates to:
  /// **'document'**
  String get documentFallbackName;

  /// Relative date for a document opened today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// Relative date for a document opened yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// Relative date for a document opened a few days ago
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day ago} other{{days} days ago}}'**
  String dateDaysAgo(int days);

  /// Error shown when the picked file has no readable bytes
  ///
  /// In en, this message translates to:
  /// **'Unable to read the file.'**
  String get errorCannotReadFile;

  /// Error shown when the picked file has an unsupported extension
  ///
  /// In en, this message translates to:
  /// **'Unsupported format: .{ext}'**
  String errorUnsupportedFormat(String ext);

  /// Generic error shown when opening a document fails unexpectedly
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while opening the document.'**
  String get errorUnexpectedOpening;

  /// Error shown when a recent file can no longer be opened from cache
  ///
  /// In en, this message translates to:
  /// **'Cache no longer available for \"{name}\". Open it manually.'**
  String errorCacheUnavailable(String name);

  /// Default name shown for a document without a title
  ///
  /// In en, this message translates to:
  /// **'Untitled document'**
  String get untitledDocument;

  /// Placeholder text shown in the empty editor
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get editorPlaceholder;

  /// Caption shown in the editor app bar after a draft is auto-saved
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// Tooltip of the save button when the document already has a file
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label used for the save-as action, dialog title and menu item
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get saveAs;

  /// Tooltip of the editor overflow menu
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Overflow menu item that exports the document as Markdown
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown (.md)'**
  String get exportAsMarkdown;

  /// Overflow menu item that exports the document as plain text
  ///
  /// In en, this message translates to:
  /// **'Export as plain text (.txt)'**
  String get exportAsText;

  /// Confirmation shown after the document is saved in place
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Confirmation shown after the document is saved to a new file
  ///
  /// In en, this message translates to:
  /// **'Saved: {fileName}'**
  String savedAs(String fileName);

  /// Confirmation shown after the document is exported
  ///
  /// In en, this message translates to:
  /// **'Exported: {fileName}'**
  String exported(String fileName);

  /// Error shown when saving the document fails
  ///
  /// In en, this message translates to:
  /// **'Error while saving: {error}'**
  String errorSaving(String error);

  /// Error shown when exporting the document fails
  ///
  /// In en, this message translates to:
  /// **'Error while exporting: {error}'**
  String errorExporting(String error);

  /// Title of the system save dialog used when exporting
  ///
  /// In en, this message translates to:
  /// **'Export as {format}'**
  String exportDialogTitle(String format);

  /// Label of the file name field in the Save as dialog
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileNameLabel;

  /// Label of the destination folder field in the Save as dialog
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folderLabel;

  /// Button that lets the user pick a different destination folder
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// Button that dismisses the Save as dialog without saving
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Title of the system folder picker shown from the Save as dialog
  ///
  /// In en, this message translates to:
  /// **'Choose save folder'**
  String get chooseFolderDialogTitle;

  /// Error shown when an .odt file is not a valid ZIP archive
  ///
  /// In en, this message translates to:
  /// **'This file does not look like a valid .odt document.'**
  String get odfErrorInvalidArchive;

  /// Error shown when an .odt archive has no content.xml entry
  ///
  /// In en, this message translates to:
  /// **'The document is incomplete: content.xml is missing.'**
  String get odfErrorMissingContent;

  /// Error shown when content.xml is not well-formed XML
  ///
  /// In en, this message translates to:
  /// **'The document content is corrupted.'**
  String get odfErrorMalformedXml;

  /// Error shown for an unclassified failure while parsing an .odt file
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while processing the document.'**
  String get odfErrorUnknown;

  /// Error shown when an imported file is not valid UTF-8 text
  ///
  /// In en, this message translates to:
  /// **'The file is not valid UTF-8 text.'**
  String get conversionErrorNotValidUtf8;

  /// Error shown when a Markdown file cannot be converted to a document
  ///
  /// In en, this message translates to:
  /// **'The Markdown file could not be converted.'**
  String get conversionErrorMarkdownFailed;

  /// Error shown when an ODF file is opened as plain text
  ///
  /// In en, this message translates to:
  /// **'This file looks like an ODF document, not plain text. Rename it to .odt and open it with \"Open\".'**
  String get conversionErrorOdfNotPlainText;
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
    'that was used.',
  );
}
