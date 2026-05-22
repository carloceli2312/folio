import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:folio/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

/// Dialog "Salva con nome": chiede nome file e cartella di destinazione.
class SaveAsDialog extends StatefulWidget {
  const SaveAsDialog({
    super.key,
    required this.initialName,
    this.initialFolder,
  });

  final String initialName;

  /// Cartella suggerita di default. Se non null, viene usata SENZA caricare
  /// `_folioDirectory()` — utile per "Salva con nome" che parte dal path
  /// corrente del documento (creazione di copie nella stessa cartella).
  final Directory? initialFolder;

  @override
  State<SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<SaveAsDialog> {
  late final TextEditingController _nameCtrl;
  Directory? _folder;
  bool _loadingFolder = true;
  bool _pickingFolder = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    if (widget.initialFolder != null) {
      _folder = widget.initialFolder;
      _loadingFolder = false;
    } else {
      _initFolder();
    }
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
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pickingFolder = true);
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.chooseFolderDialogTitle,
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
    final l10n = AppLocalizations.of(context)!;
    final canSave = !_loadingFolder && _folder != null;
    return AlertDialog(
      title: Text(l10n.saveAs),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.fileNameLabel,
              suffixText: '.odt',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 20),
          Text(l10n.folderLabel, style: Theme.of(context).textTheme.labelMedium),
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
                child: Text(l10n.change),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canSave ? _confirm : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Restituisce la directory di salvataggio predefinita di Folio.
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
