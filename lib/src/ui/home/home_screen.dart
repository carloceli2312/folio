
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:folio/l10n/app_localizations.dart';
import 'package:folio/src/converters/conversion_exception.dart';
import 'package:folio/src/converters/converter.dart';
import 'package:folio/src/converters/md_converter.dart';
import 'package:folio/src/converters/txt_converter.dart';
import 'package:folio/src/odf/odf_exceptions.dart';
import 'package:folio/src/odf/odf_parser.dart';
import 'package:folio/src/services/draft.dart';
import 'package:folio/src/services/draft_service.dart';
import 'package:folio/src/services/recent_file.dart';
import 'package:folio/src/services/recent_files_service.dart';
import 'package:folio/src/ui/editor/editor_screen.dart';
import 'package:folio/src/ui/home/widgets/home_empty_state.dart';
import 'package:folio/src/ui/home/widgets/home_header.dart';
import 'package:folio/src/ui/home/widgets/loading_overlay.dart';
import 'package:folio/src/ui/home/widgets/recents_list.dart';

/// Home screen — entry point of the app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RecentFilesService _recentFiles = RecentFilesService();
  final DraftService _draftService = DraftService();

  List<RecentFile> _recents = const [];
  Draft? _draft;

  bool _isOpening = false;
  bool _isParsing = false;

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _loadDraft();
  }

  Future<void> _loadRecents() async {
    final list = await _recentFiles.load();
    if (!mounted) return;
    setState(() => _recents = list);
  }

  Future<void> _loadDraft() async {
    final draft = await _draftService.load();
    if (!mounted) return;
    setState(() => _draft = draft);
  }

  /// Ricarica recenti + bozza dopo il rientro dall'editor.
  Future<void> _reloadFromDisk() async {
    if (!mounted) return;
    await _loadRecents();
    await _loadDraft();
  }

  Future<void> _resumeDraft() async {
    final draft = _draft;
    if (draft == null) return;
    final delta = Delta.fromJson(draft.deltaOps);
    final controller = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    await Navigator.of(context).push(
      _slideRoute(
        EditorScreen(
          controller: controller,
          fileName: draft.fileName,
          savedPath: draft.savedPath,
        ),
      ),
    );
    await _reloadFromDisk();
  }

  Future<void> _discardDraft() async {
    await _draftService.clear();
    if (!mounted) return;
    setState(() => _draft = null);
  }

  static const Map<String, DocumentConverter> _converters = {
    'txt': TxtConverter(),
    'md': MdConverter(),
  };

  /// Flusso principale: scegli file → leggi bytes → parsa su isolate →
  /// costruisci il controller → promuovi nei recenti → apri l'editor.
  Future<void> _openDocument() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isOpening = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['odt', 'txt', 'md'],
        withData:
            true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        _showError(l10n.errorCannotReadFile);
        return;
      }

      if (mounted) setState(() => _isParsing = true);

      final Delta delta;
      try {
        final ext = file.extension?.toLowerCase() ?? '';
        if (ext == 'odt') {
          delta = await compute(OdfParser.parse, bytes);
        } else {
          final converter = _converters[ext];
          if (converter == null) {
            _showError(l10n.errorUnsupportedFormat(ext));
            return;
          }
          delta = await compute(_runConverter, (converter, bytes));
        }
      }
      on OdfException catch (e) {
        _showError(_odfErrorMessage(l10n, e));
        debugPrint('ODF parse failed: $e');
        return;
      } on ConversionException catch (e) {
        _showError(_conversionErrorMessage(l10n, e));
        debugPrint('Conversion failed: $e');
        return;
      } catch (e) {
        _showError(l10n.errorUnexpectedOpening);
        debugPrint('Unexpected parse error: $e');
        return;
      } finally {
        if (mounted) setState(() => _isParsing = false);
      }

      final document = Document.fromDelta(delta);
      final controller = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );

      final preview = RecentFilesService.previewFromDeltaOps(delta.toJson());
      final updated = await _recentFiles.addOrPromote(
        RecentFile(name: file.name, preview: preview, openedAt: DateTime.now()),
        bytes: bytes,
      );
      if (mounted) setState(() => _recents = updated);

      if (!mounted) return;
      await Navigator.of(context).push(
        _slideRoute(EditorScreen(controller: controller, fileName: file.name)),
      );
      await _reloadFromDisk();
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  /// Apre un documento direttamente dalla cache di un'entry recente,
  /// senza passare dal SAF picker. Se la cache non è disponibile (entry
  /// legacy o file rimosso esternamente) ricade sul picker mostrando un
  /// messaggio informativo.
  Future<void> _openRecent(RecentFile entry) async {
    if (_isOpening) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isOpening = true);
    try {
      final bytes = await _recentFiles.readCached(entry);
      if (bytes == null) {
        _showError(l10n.errorCacheUnavailable(entry.name));
        await _openDocument();
        return;
      }

      if (mounted) setState(() => _isParsing = true);

      final Delta delta;
      try {
        delta = await compute(OdfParser.parse, bytes);
      } on OdfException catch (e) {
        _showError(_odfErrorMessage(l10n, e));
        debugPrint('Recent open failed: $e');
        return;
      } catch (e) {
        _showError(l10n.errorUnexpectedOpening);
        debugPrint('Unexpected recent open error: $e');
        return;
      } finally {
        if (mounted) setState(() => _isParsing = false);
      }

      final updated = await _recentFiles.addOrPromote(
        RecentFile(
          name: entry.name,
          preview: entry.preview,
          openedAt: DateTime.now(),
          cachedPath: entry.cachedPath,
          userPath: entry.userPath,
        ),
      );
      if (mounted) setState(() => _recents = updated);

      final controller = QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        _slideRoute(
          EditorScreen(
            controller: controller,
            fileName: entry.name,
            savedPath: entry.userPath,
          ),
        ),
      );
      await _reloadFromDisk();
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _newDocument() async {
    final controller = QuillController.basic();
    final fileName = '${AppLocalizations.of(context)!.newDocument}.odt';
    await Navigator.of(context).push(
      _slideRoute(
        EditorScreen(controller: controller, fileName: fileName),
      ),
    );
    await _reloadFromDisk();
  }

  /// Slide-up page transition for the editor.
  PageRoute<T> _slideRoute<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final tween = Tween(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(tween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasContent = _recents.isNotEmpty || _draft != null;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeader(isOpening: _isOpening, onOpen: _openDocument),
                const Divider(),
                Expanded(
                  child: hasContent
                      ? RecentsList(
                          recents: _recents,
                          draft: _draft,
                          isOpening: _isOpening,
                          onResumeDraft: _resumeDraft,
                          onDiscardDraft: _discardDraft,
                          onOpenRecent: _openRecent,
                        )
                      : HomeEmptyState(
                          isOpening: _isOpening,
                          onOpen: _openDocument,
                        ),
                ),
              ],
            ),
          ),
          if (_isParsing)
            LoadingOverlay(message: l10n.loadingOpeningDocument),
        ],
      ),
      floatingActionButton: _isParsing
          ? null
          : FloatingActionButton(
              heroTag: null,
              onPressed: _newDocument,
              tooltip: l10n.newDocument,
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// Esegue la conversione su isolate via compute().
Delta _runConverter((DocumentConverter, Uint8List) args) {
  final (converter, bytes) = args;
  return converter.fromBytes(bytes);
}

/// Maps an [OdfException] to a localized, user-facing message.
String _odfErrorMessage(AppLocalizations l10n, OdfException e) => switch (e) {
  OdfInvalidArchiveException() => l10n.odfErrorInvalidArchive,
  OdfMissingContentException() => l10n.odfErrorMissingContent,
  OdfMalformedXmlException() => l10n.odfErrorMalformedXml,
  OdfUnknownException() => l10n.odfErrorUnknown,
};

/// Maps a [ConversionException] to a localized, user-facing message.
String _conversionErrorMessage(AppLocalizations l10n, ConversionException e) =>
    switch (e.kind) {
      ConversionErrorKind.notValidUtf8 => l10n.conversionErrorNotValidUtf8,
      ConversionErrorKind.markdownConversionFailed =>
        l10n.conversionErrorMarkdownFailed,
      ConversionErrorKind.odfFileNotPlainText =>
        l10n.conversionErrorOdfNotPlainText,
    };
