import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'app_theme.dart';
import 'converters/md_converter.dart';
import 'converters/txt_converter.dart';
import 'draft_service.dart';
import 'odf_serializer.dart';
import 'recent_files_service.dart';

/// Full-screen document editor.
///
/// Layout (Studio direction):
/// - Dark AppBar with back button, file name (read-only), save action
/// - QuillEditor filling the body (warm cream background)
/// - Dark formatting toolbar pinned at the bottom
///
/// [savedPath] è il path locale del file ODT corrente (null = documento nuovo
/// o importato via SAF senza ancora un salvataggio locale). Quando null, il
/// pulsante "Salva" è disabilitato e il primo salvataggio passa per il dialog
/// "Salva con nome".
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.controller,
    required this.fileName,
    this.savedPath,
  });

  final QuillController controller;

  /// Nome file iniziale (con estensione), usato come default nel dialog
  /// "Salva con nome" e mostrato (senza estensione) nell'AppBar.
  final String fileName;

  /// Path locale del file ODT già salvato. Null per documenti nuovi o
  /// importati via SAF (che non hanno ancora un path locale stabile).
  final String? savedPath;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const Duration _draftDebounce = Duration(seconds: 2);

  late final QuillController _controller;
  late final TextEditingController _titleCtrl;

  /// Nome visualizzato nell'AppBar (senza estensione .odt).
  late String _displayName;

  /// Path locale del file ODT corrente. Null = non ancora salvato localmente.
  String? _savedPath;

  bool get _hasSavedFile => _savedPath != null;

  String get _effectiveDisplayName {
    final t = _titleCtrl.text.trim();
    return t.isEmpty ? 'Documento senza titolo' : t;
  }

  final RecentFilesService _recentFiles = RecentFilesService();
  final DraftService _draftService = DraftService();
  StreamSubscription<dynamic>? _docChangesSub;
  Timer? _draftTimer;
  DateTime? _draftSavedAt;
  bool _isSaving = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _savedPath = widget.savedPath;
    _displayName = widget.fileName.replaceAll(
      RegExp(r'\.odt$', caseSensitive: false),
      '',
    );
    _titleCtrl = TextEditingController(text: _displayName);
    _docChangesSub = _controller.document.changes.listen(_onDocChanged);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _docChangesSub?.cancel();
    _titleCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDocChanged(dynamic _) {
    _draftTimer?.cancel();
    _draftTimer = Timer(_draftDebounce, _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      await _draftService.save(
        Draft(
          fileName: '$_effectiveDisplayName.odt',
          deltaOps: _controller.document.toDelta().toJson(),
          savedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() => _draftSavedAt = DateTime.now());
    } catch (e) {
      debugPrint('Draft save failed: $e');
    }
  }

  // ─── Save (overwrite) ────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_isSaving || _savedPath == null) return;
    setState(() => _isSaving = true);
    try {
      final newName = _effectiveDisplayName;
      final newFileName = '$newName.odt';
      final delta = _controller.document.toDelta();
      final bytes = OdfSerializer.serialize(delta);

      final oldFile = File(_savedPath!);
      final sep = Platform.pathSeparator;
      final newPath = '${oldFile.parent.path}$sep$newFileName';

      if (newPath != _savedPath) {
        await File(newPath).writeAsBytes(bytes, flush: true);
        try {
          await oldFile.delete();
        } catch (_) {}
      } else {
        await oldFile.writeAsBytes(bytes, flush: true);
      }

      await _recentFiles.addOrPromote(
        RecentFile(
          name: newFileName,
          preview: RecentFilesService.previewFromDeltaOps(delta.toJson()),
          openedAt: DateTime.now(),
          cachedPath: newPath,
        ),
        bytes: bytes,
      );

      _draftTimer?.cancel();
      await _draftService.clear();

      if (!mounted) return;
      setState(() {
        _savedPath = newPath;
        _displayName = newName;
        _draftSavedAt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvato')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel salvataggio: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Save As ────────────────────────────────────────────────────────────

  Future<void> _saveAs() async {
    if (_isSaving) return;

    final result = await showDialog<({String filePath, String displayName})>(
      context: context,
      builder: (_) => _SaveAsDialog(initialName: _effectiveDisplayName),
    );
    if (result == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final delta = _controller.document.toDelta();
      final bytes = OdfSerializer.serialize(delta);

      final file = File(result.filePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);

      final fileName = '${result.displayName}.odt';
      final updated = await _recentFiles.addOrPromote(
        RecentFile(
          name: fileName,
          preview: RecentFilesService.previewFromDeltaOps(delta.toJson()),
          openedAt: DateTime.now(),
        ),
        bytes: bytes,
      );
      final cachedPath = updated.firstWhere((e) => e.name == fileName,
          orElse: () => updated.first).cachedPath;

      _draftTimer?.cancel();
      await _draftService.clear();

      if (!mounted) return;
      setState(() {
        _savedPath = cachedPath ?? result.filePath;
        _displayName = result.displayName;
        _draftSavedAt = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvato: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel salvataggio: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Export ─────────────────────────────────────────────────────────────

  Future<void> _exportAs(String format) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final delta = _controller.document.toDelta();
      final Uint8List bytes;
      final String fileName;
      switch (format) {
        case 'txt':
          bytes = const TxtConverter().toBytes(delta);
          fileName = '$_effectiveDisplayName.txt';
        case 'md':
          bytes = const MdConverter().toBytes(delta);
          fileName = '$_effectiveDisplayName.md';
        default:
          return;
      }
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Esporta come $format',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [format],
        bytes: bytes,
      );
      if (savedPath == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Esportato: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nell\'esportazione: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitleField(),
          const Divider(height: 1),
          Expanded(child: _buildEditor()),
          _buildFormattingToolbar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _effectiveDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_draftSavedAt != null)
            const Text(
              'Bozza salvata',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: [
        if (_isSaving || _isExporting)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Salva',
            // Disabilitato finché il documento non ha un path locale.
            onPressed: _hasSavedFile ? _save : null,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Altro',
            onSelected: (value) {
              if (value == 'save_as') {
                _saveAs();
              } else {
                _exportAs(value);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'save_as',
                child: ListTile(
                  leading: Icon(Icons.save_as_outlined),
                  title: Text('Salva con nome'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'md',
                enabled: _hasSavedFile,
                child: ListTile(
                  leading: Icon(
                    Icons.code_outlined,
                    color: _hasSavedFile ? null : Colors.black26,
                  ),
                  title: Text(
                    'Esporta come Markdown (.md)',
                    style: _hasSavedFile
                        ? null
                        : const TextStyle(color: Colors.black26),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'txt',
                enabled: _hasSavedFile,
                child: ListTile(
                  leading: Icon(
                    Icons.text_snippet_outlined,
                    color: _hasSavedFile ? null : Colors.black26,
                  ),
                  title: Text(
                    'Esporta come testuale (.txt)',
                    style: _hasSavedFile
                        ? null
                        : const TextStyle(color: Colors.black26),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: TextField(
        controller: _titleCtrl,
        style: GoogleFonts.lora(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          height: 1.2,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Documento senza titolo',
          hintStyle: TextStyle(color: AppTheme.textSecondary),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        textCapitalization: TextCapitalization.sentences,
        maxLines: 1,
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: QuillEditor.basic(
        controller: _controller,
        config: QuillEditorConfig(
          placeholder: 'Inizia a scrivere…',
          customStyles: _buildEditorStyles(),
        ),
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkChrome,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            iconTheme: const IconThemeData(color: Colors.white70, size: 22),
            iconButtonTheme: IconButtonThemeData(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white70;
                }),
                overlayColor: WidgetStateProperty.all(Colors.white12),
                minimumSize: WidgetStateProperty.all(const Size(44, 44)),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),
          child: QuillSimpleToolbar(
            controller: _controller,
            config: QuillSimpleToolbarConfig(
              color: AppTheme.darkChrome,
              multiRowsDisplay: true,
              toolbarRunSpacing: 0,
              toolbarSectionSpacing: 4,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: true,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showFontFamily: false,
              showFontSize: false,
              showSubscript: false,
              showSuperscript: false,
              showAlignmentButtons: false,
              showLeftAlignment: false,
              showCenterAlignment: false,
              showRightAlignment: false,
              showJustifyAlignment: false,
              showHeaderStyle: true,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showSearchButton: false,
              showUndo: true,
              showRedo: true,
              showDirection: false,
              showDividers: true,
              iconTheme: const QuillIconTheme(
                iconButtonUnselectedData: IconButtonData(
                  color: Colors.white70,
                  iconSize: 22,
                ),
                iconButtonSelectedData: IconButtonData(
                  color: Colors.white,
                  iconSize: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DefaultStyles _buildEditorStyles() {
    return DefaultStyles(
      h1: DefaultTextBlockStyle(
        GoogleFonts.lora(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: AppTheme.textPrimary,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(20, 4),
        const VerticalSpacing(0, 0),
        null,
      ),
      h2: DefaultTextBlockStyle(
        GoogleFonts.lora(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.25,
          color: AppTheme.textPrimary,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(16, 4),
        const VerticalSpacing(0, 0),
        null,
      ),
      h3: DefaultTextBlockStyle(
        GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTheme.textPrimary,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(12, 4),
        const VerticalSpacing(0, 0),
        null,
      ),
      paragraph: DefaultTextBlockStyle(
        const TextStyle(
          fontSize: 16,
          height: 1.7,
          color: AppTheme.textPrimary,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(0, 6),
        const VerticalSpacing(0, 0),
        null,
      ),
    );
  }
}

// ─── Save As Dialog ─────────────────────────────────────────────────────────

class _SaveAsDialog extends StatefulWidget {
  const _SaveAsDialog({required this.initialName});

  final String initialName;

  @override
  State<_SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<_SaveAsDialog> {
  late final TextEditingController _nameCtrl;
  Directory? _folder;
  bool _loadingFolder = true;
  bool _pickingFolder = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _initFolder();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initFolder() async {
    final dir = await _folioDirectory();
    if (!mounted) return;
    setState(() {
      _folder = dir;
      _loadingFolder = false;
    });
  }

  Future<void> _pickFolder() async {
    setState(() => _pickingFolder = true);
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Scegli cartella di salvataggio',
      );
      if (path != null && mounted) {
        setState(() => _folder = Directory(path));
      }
    } finally {
      if (mounted) setState(() => _pickingFolder = false);
    }
  }

  String get _folderLabel {
    final path = _folder?.path;
    if (path == null) return '—';
    final sep = Platform.pathSeparator;
    final parts = path.split(sep).where((s) => s.isNotEmpty).toList();
    if (parts.length <= 2) return path;
    return '…$sep${parts[parts.length - 2]}$sep${parts.last}';
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _folder == null) return;
    final sep = Platform.pathSeparator;
    final filePath = '${_folder!.path}$sep$name.odt';
    Navigator.of(context).pop((filePath: filePath, displayName: name));
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_loadingFolder && _folder != null;
    return AlertDialog(
      title: const Text('Salva con nome'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome file',
              suffixText: '.odt',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 20),
          Text(
            'Cartella',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _loadingFolder
                    ? const LinearProgressIndicator()
                    : Text(
                        _folderLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _pickingFolder ? null : _pickFolder,
                child: const Text('Cambia'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: canSave ? _confirm : null,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Restituisce la directory di salvataggio predefinita di Folio.
///
/// Prova prima lo storage esterno app-specifico (visibile nel file manager
/// sotto Android/data, senza permessi su Android 10+), poi ricade su
/// getApplicationSupportDirectory (storage privato).
Future<Directory> _folioDirectory() async {
  try {
    final ext = await getExternalStorageDirectory();
    if (ext != null) {
      final dir = Directory('${ext.path}/Folio');
      await dir.create(recursive: true);
      return dir;
    }
  } catch (_) {}
  final app = await getApplicationSupportDirectory();
  final dir = Directory('${app.path}/Folio');
  await dir.create(recursive: true);
  return dir;
}
