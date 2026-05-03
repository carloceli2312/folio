import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'app_theme.dart';
import 'converters/converter.dart';
import 'converters/md_converter.dart';
import 'converters/txt_converter.dart';
import 'draft_service.dart';
import 'editor_screen.dart';
import 'odf_exceptions.dart';
import 'odf_parser.dart';
import 'recent_files_service.dart';
import 'widgets/animated_folio_logo.dart';

/// Home screen — entry point of the app.
///
/// Shows the Folio branding and actions to open an existing .odt file
/// or create a new blank document.
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
        EditorScreen(controller: controller, fileName: draft.fileName),
      ),
    );
    if (mounted) {
      await _loadRecents();
      await _loadDraft();
    }
  }

  Future<void> _discardDraft() async {
    await _draftService.clear();
    if (!mounted) return;
    setState(() => _draft = null);
  }

  // Converter registrati per estensione (ODT è gestito da OdfParser).
  static const Map<String, DocumentConverter> _converters = {
    'txt': TxtConverter(),
    'md': MdConverter(),
  };

  Future<void> _openDocument() async {
    setState(() => _isOpening = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['odt', 'txt', 'md'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        _showError('Impossibile leggere il file.');
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
            _showError('Formato non supportato: .$ext');
            return;
          }
          delta = await compute(_runConverter, (converter, bytes));
        }
      } on OdfException catch (e) {
        _showError(e.userMessage);
        debugPrint('ODF parse failed: $e');
        return;
      } on ConversionException catch (e) {
        _showError(e.userMessage);
        debugPrint('Conversion failed: $e');
        return;
      } catch (e) {
        _showError('Errore imprevisto durante l\'apertura.');
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

      // Promuovi (o aggiungi) il file nei recenti, cachando i bytes
      // per consentire la riapertura istantanea (no SAF picker).
      final preview = RecentFilesService.previewFromDeltaOps(delta.toJson());
      final updated = await _recentFiles.addOrPromote(
        RecentFile(
          name: file.name,
          preview: preview,
          openedAt: DateTime.now(),
        ),
        bytes: bytes,
      );
      if (mounted) setState(() => _recents = updated);

      if (!mounted) return;
      await Navigator.of(context).push(
        _slideRoute(EditorScreen(controller: controller, fileName: file.name)),
      );
      // Al rientro dall'editor il salvataggio potrebbe aver aggiunto voci.
      if (mounted) await _loadRecents();
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
    setState(() => _isOpening = true);
    try {
      final bytes = await _recentFiles.readCached(entry);
      if (bytes == null) {
        _showError(
          'Cache non più disponibile per "${entry.name}". Aprilo manualmente.',
        );
        await _openDocument();
        return;
      }

      if (mounted) setState(() => _isParsing = true);

      final Delta delta;
      try {
        delta = await compute(OdfParser.parse, bytes);
      } on OdfException catch (e) {
        _showError(e.userMessage);
        debugPrint('Recent open failed: $e');
        return;
      } catch (e) {
        _showError('Errore imprevisto durante l\'apertura.');
        debugPrint('Unexpected recent open error: $e');
        return;
      } finally {
        if (mounted) setState(() => _isParsing = false);
      }

      // Promuovi in cima senza ri-cachare (i bytes sono identici).
      final updated = await _recentFiles.addOrPromote(
        RecentFile(
          name: entry.name,
          preview: entry.preview,
          openedAt: DateTime.now(),
          cachedPath: entry.cachedPath,
        ),
      );
      if (mounted) setState(() => _recents = updated);

      final controller = QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        _slideRoute(EditorScreen(
          controller: controller,
          fileName: entry.name,
          savedPath: entry.cachedPath,
        )),
      );
      if (mounted) await _loadRecents();
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _newDocument() async {
    final controller = QuillController.basic();
    await Navigator.of(context).push(
      _slideRoute(
        EditorScreen(controller: controller, fileName: 'Nuovo documento.odt'),
      ),
    );
    if (mounted) await _loadRecents();
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
          child: SlideTransition(position: animation.drive(tween), child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const Divider(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          if (_isParsing) const _LoadingOverlay(message: 'Apertura documento…'),
        ],
      ),
      floatingActionButton: _isParsing
          ? null
          : FloatingActionButton(
              // heroTag: null disabilita l'animazione Hero sul FAB, evitando
              // il conflitto con altri scaffold durante le transizioni di pagina.
              heroTag: null,
              onPressed: _newDocument,
              tooltip: 'Nuovo documento',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folio', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 4),
                Text(
                  'Editor di documenti',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          _isOpening
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _openDocument,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Apri'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final hasRecents = _recents.isNotEmpty;
    final hasDraft = _draft != null;
    if (!hasRecents && !hasDraft) return _buildEmptyState();
    return _buildList(hasDraft: hasDraft);
  }

  Widget _buildList({required bool hasDraft}) {
    final headerCount = hasDraft ? 1 : 0;
    final sectionTitle = _recents.isNotEmpty ? 1 : 0;
    final totalCount = headerCount + sectionTitle + _recents.length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: totalCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        var i = index;
        if (hasDraft && i == 0) {
          return _DraftBanner(
            draft: _draft!,
            onResume: _isOpening ? null : _resumeDraft,
            onDiscard: _isOpening ? null : _discardDraft,
          );
        }
        if (hasDraft) i--;
        if (sectionTitle == 1 && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4, left: 4),
            child: Text(
              'Recenti',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          );
        }
        if (sectionTitle == 1) i--;
        final file = _recents[i];
        return _RecentFileCard(
          file: file,
          onTap: _isOpening ? null : () => _openRecent(file),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedFolioLogo(size: 80),
            const SizedBox(height: 20),
            Text(
              'Nessun documento recente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Apri un file .odt esistente o crea\nun nuovo documento per iniziare.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _isOpening ? null : _openDocument,
              icon: const Icon(Icons.folder_open_outlined, size: 16),
              label: const Text('Apri documento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.divider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner che propone di riprendere una bozza non salvata.
class _DraftBanner extends StatelessWidget {
  const _DraftBanner({
    required this.draft,
    required this.onResume,
    required this.onDiscard,
  });

  final Draft draft;
  final VoidCallback? onResume;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppTheme.darkChrome,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.history_edu_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bozza non salvata',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tocca per riprendere ${_safeName(draft.fileName)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Scarta bozza',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onDiscard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safeName(String fileName) {
    final stripped = fileName.replaceAll(
      RegExp(r'\.odt$', caseSensitive: false),
      '',
    );
    return stripped.isEmpty ? 'documento' : stripped;
  }
}

/// Card per un singolo documento recente.
///
/// Tap → apre il file picker (i path SAF non sono stabili tra sessioni,
/// quindi la card è informativa e non riapre direttamente il documento).
class _RecentFileCard extends StatelessWidget {
  const _RecentFileCard({required this.file, required this.onTap});

  final RecentFile file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = file.name.replaceAll(
      RegExp(r'\.odt$', caseSensitive: false),
      '',
    );
    return Material(
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.pageBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 22,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (file.preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        file.preview,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _formatRelativeDate(file.openedAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Esegue la conversione su isolate via compute().
///
/// Top-level per compatibilità con compute() che richiede funzioni statiche
/// o top-level.
Delta _runConverter((DocumentConverter, Uint8List) args) {
  final (converter, bytes) = args;
  return converter.fromBytes(bytes);
}

/// Restituisce una stringa relativa in italiano (es. "oggi", "ieri",
/// "3 giorni fa", "12/03/2026") basata su [date].
String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(date.year, date.month, date.day);
  final days = today.difference(that).inDays;
  if (days <= 0) return 'Oggi';
  if (days == 1) return 'Ieri';
  if (days < 7) return '$days giorni fa';
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$dd/$mm/${date.year}';
}

/// Overlay modale a schermo intero con spinner + messaggio.
///
/// Usato durante operazioni potenzialmente lunghe (parsing/serializzazione
/// di file pesanti) per dare feedback all'utente e bloccare l'interazione.
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.darkChrome,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
