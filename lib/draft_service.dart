import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Una bozza non salvata: snapshot del contenuto dell'editor in un certo
/// istante, persistito su storage app-private.
///
/// Le bozze sono usate come rete di sicurezza contro chiusure inattese
/// dell'app prima del salvataggio "Save As" via SAF — non sono un sostituto
/// del salvataggio esplicito.
class Draft {
  const Draft({
    required this.fileName,
    required this.deltaOps,
    required this.savedAt,
  });

  /// Nome file proposto al prossimo "Save As" (titolo correlato).
  final String fileName;

  /// Delta serializzato come JSON (lista di operazioni).
  final List<dynamic> deltaOps;

  /// Quando la bozza è stata persistita.
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'deltaOps': deltaOps,
        'savedAt': savedAt.toIso8601String(),
      };

  static Draft? fromJson(Map<String, dynamic> json) {
    final fileName = json['fileName'];
    final ops = json['deltaOps'];
    final savedAt = json['savedAt'];
    if (fileName is! String || ops is! List || savedAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(savedAt);
    if (parsed == null) return null;
    return Draft(fileName: fileName, deltaOps: ops, savedAt: parsed);
  }
}

/// Persistenza di una singola bozza non salvata.
///
/// Implementazione: file `draft.json` in
/// [getApplicationSupportDirectory], app-private (non visibile a utente o
/// altre app, sopravvive ai riavvii ma non al cleardata).
///
/// Per i test, [directory] può essere iniettata.
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
