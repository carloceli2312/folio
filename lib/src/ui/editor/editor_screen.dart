import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:folio/l10n/app_localizations.dart';
import 'package:folio/src/app/app_theme.dart';
import 'package:folio/src/converters/md_converter.dart';
import 'package:folio/src/converters/txt_converter.dart';
import 'package:folio/src/odf/odf_serializer.dart';
import 'package:folio/src/services/draft.dart';
import 'package:folio/src/services/draft_service.dart';
import 'package:folio/src/services/recent_file.dart';
import 'package:folio/src/services/recent_files_service.dart';
import 'package:folio/src/ui/editor/save_as_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen document editor.
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
    return t.isEmpty ? AppLocalizations.of(context)!.untitledDocument : t;
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
          savedPath: _savedPath,
        ),
      );
      if (!mounted) return;
      setState(() => _draftSavedAt = DateTime.now());
    } catch (e) {
      debugPrint('Draft save failed: $e');
    }
  }

  Future<void> _save() async {
    if (_isSaving || _savedPath == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final newName = _effectiveDisplayName;
      final newFileName = '$newName.odt';
      final oldFileName = '$_displayName.odt';
      final delta = _controller.document.toDelta();
      final bytes = OdfSerializer.serialize(delta);

      final oldUserFile = File(_savedPath!);
      final sep = Platform.pathSeparator;
      final newUserPath = '${oldUserFile.parent.path}$sep$newFileName';
      final renamed = newUserPath != _savedPath;

      if (renamed) {
        await File(newUserPath).writeAsBytes(bytes, flush: true);
        try {
          await oldUserFile.delete();
        } catch (_) {}
        await _recentFiles.remove(
          RecentFile(
            name: oldFileName,
            preview: '',
            openedAt: DateTime.now(),
          ),
        );
      } else {
        await oldUserFile.writeAsBytes(bytes, flush: true);
      }

      await _recentFiles.addOrPromote(
        RecentFile(
          name: newFileName,
          preview: RecentFilesService.previewFromDeltaOps(delta.toJson()),
          openedAt: DateTime.now(),
          userPath: newUserPath,
        ),
        bytes: bytes,
      );

      _draftTimer?.cancel();
      await _draftService.clear();

      if (!mounted) return;
      setState(() {
        _savedPath = newUserPath;
        _displayName = newName;
        _draftSavedAt = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorSaving(e.toString()))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAs() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;

    final Directory? initialFolder = _savedPath != null
        ? File(_savedPath!).parent
        : null;

    final result = await showDialog<({String filePath, String displayName})>(
      context: context,
      builder: (_) => SaveAsDialog(
        initialName: _effectiveDisplayName,
        initialFolder: initialFolder,
      ),
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
      await _recentFiles.addOrPromote(
        RecentFile(
          name: fileName,
          preview: RecentFilesService.previewFromDeltaOps(delta.toJson()),
          openedAt: DateTime.now(),
          userPath: result.filePath,
        ),
        bytes: bytes,
      );

      _draftTimer?.cancel();
      await _draftService.clear();

      if (!mounted) return;
      setState(() {
        _savedPath = result.filePath;
        _displayName = result.displayName;
        _draftSavedAt = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.savedAs(fileName))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorSaving(e.toString()))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportAs(String format) async {
    if (_isExporting) return;
    final l10n = AppLocalizations.of(context)!;
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
        dialogTitle: l10n.exportDialogTitle(format),
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [format],
        bytes: bytes,
      );
      if (savedPath == null || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.exported(fileName))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorExporting(e.toString()))));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

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
    final l10n = AppLocalizations.of(context)!;
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
            Text(
              l10n.draftSaved,
              style: const TextStyle(
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
            tooltip: _hasSavedFile ? l10n.save : l10n.saveAs,
            onPressed: _hasSavedFile ? _save : _saveAs,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.more,
            onSelected: (value) {
              if (value == 'save_as') {
                _saveAs();
              } else {
                _exportAs(value);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'save_as',
                child: ListTile(
                  leading: const Icon(Icons.save_as_outlined),
                  title: Text(l10n.saveAs),
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
                    l10n.exportAsMarkdown,
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
                    l10n.exportAsText,
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
    final l10n = AppLocalizations.of(context)!;
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
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: l10n.untitledDocument,
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        textCapitalization: TextCapitalization.sentences,
        maxLines: 1,
      ),
    );
  }

  Widget _buildEditor() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: QuillEditor.basic(
        controller: _controller,
        config: QuillEditorConfig(
          placeholder: l10n.editorPlaceholder,
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
        const TextStyle(fontSize: 16, height: 1.7, color: AppTheme.textPrimary),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(0, 6),
        const VerticalSpacing(0, 0),
        null,
      ),
    );
  }
}
