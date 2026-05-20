import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'draft.dart';

/// Persistenza di una singola bozza non salvata.
class DraftService {
  DraftService({Directory? directory}) : _customDir = directory;

  static const String _fileName = 'draft.json';

  final Directory? _customDir;

  Future<File> _file() async {
    final dir = _customDir ?? await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// `true` se esiste una bozza persistita.
  Future<bool> exists() async {
    final file = await _file();
    return file.existsSync();
  }

  /// Carica la bozza, oppure `null` se assente o corrotta.
  Future<Draft?> load() async {
    final file = await _file();
    if (!file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Draft.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Scrive [draft] su disco (atomic via file temporaneo + rename).
  Future<void> save(Draft draft) async {
    final file = await _file();
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(draft.toJson()), flush: true);
    if (file.existsSync()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  /// Rimuove la bozza, se esiste.
  Future<void> clear() async {
    final file = await _file();
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
