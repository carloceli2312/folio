import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recent_file.dart';

/// Persistenza della lista "documenti recenti" via [SharedPreferences],
/// con cache binaria opzionale dei documenti in storage app-private.
class RecentFilesService {
  RecentFilesService({SharedPreferences? prefs, Directory? cacheDir})
    : _prefs = prefs,
      _customCacheDir = cacheDir;

  static const String _key = 'recent_files_v1';

  /// Numero massimo di voci memorizzate.
  static const int maxEntries = 10;

  /// Lunghezza massima dell'anteprima testo.
  static const int previewMaxLength = 120;

  SharedPreferences? _prefs;
  final Directory? _customCacheDir;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Directory> _cacheDirectory() async {
    final base = _customCacheDir ?? await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/recents');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Nome file di cache stabile e filesystem-safe per un dato display name.
  /// Usa base64url di UTF-8: deterministico, niente caratteri vietati su
  /// nessun filesystem.
  String _cacheFileNameFor(String displayName) {
    final encoded = base64UrlEncode(
      utf8.encode(displayName),
    ).replaceAll('=', '');
    return '$encoded.odt';
  }

  /// Carica la lista corrente (vuota se assente o corrotta).
  Future<List<RecentFile>> load() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecentFile.fromJson)
          .whereType<RecentFile>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Aggiunge [entry] in cima, rimuovendo eventuali voci precedenti con lo
  /// stesso [RecentFile.name], e cappa la lista a [maxEntries].
  Future<List<RecentFile>> addOrPromote(
    RecentFile entry, {
    Uint8List? bytes,
  }) async {
    final current = [...await load()];

    final previous = current.where((e) => e.name == entry.name).toList();
    current.removeWhere((e) => e.name == entry.name);

    String? cachedPath =
        entry.cachedPath ??
        (previous.isNotEmpty ? previous.first.cachedPath : null);
    final String? userPath =
        entry.userPath ??
        (previous.isNotEmpty ? previous.first.userPath : null);

    if (bytes != null) {
      final cacheDir = await _cacheDirectory();
      final cacheFile = File(
        '${cacheDir.path}/${_cacheFileNameFor(entry.name)}',
      );
      await cacheFile.writeAsBytes(bytes, flush: true);
      cachedPath = cacheFile.path;
    }

    final stored = RecentFile(
      name: entry.name,
      preview: entry.preview,
      openedAt: entry.openedAt,
      cachedPath: cachedPath,
      userPath: userPath,
    );

    current.insert(0, stored);

    final kept = current.take(maxEntries).toList(growable: false);
    final evicted = current.skip(maxEntries).toList(growable: false);
    for (final old in evicted) {
      await _deleteCacheOf(old);
    }

    final prefs = await _getPrefs();
    await prefs.setString(
      _key,
      jsonEncode(kept.map((e) => e.toJson()).toList()),
    );
    return kept;
  }

  /// Restituisce i bytes della copia in cache di [entry], oppure `null` se
  /// la voce non ha cache o se il file è stato cancellato esternamente
  /// (es. cleardata utente).
  Future<Uint8List?> readCached(RecentFile entry) async {
    final path = entry.cachedPath;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Rimuove la voce [entry] dalla lista e cancella il suo cache file.
  Future<List<RecentFile>> remove(RecentFile entry) async {
    final current = [...await load()];
    final removed = current.where((e) => e.name == entry.name).toList();
    current.removeWhere((e) => e.name == entry.name);
    for (final r in removed) {
      await _deleteCacheOf(r);
    }
    final prefs = await _getPrefs();
    await prefs.setString(
      _key,
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
    return current;
  }

  /// Rimuove tutte le voci e i loro file di cache.
  Future<void> clear() async {
    final list = await load();
    for (final e in list) {
      await _deleteCacheOf(e);
    }
    final prefs = await _getPrefs();
    await prefs.remove(_key);
  }

  Future<void> _deleteCacheOf(RecentFile entry) async {
    final path = entry.cachedPath;
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {
      }
    }
  }

  /// Estrae un'anteprima testuale dai primi [previewMaxLength] caratteri di
  /// un Delta serializzato come JSON (lista di operazioni `{insert: ...}`).
  static String previewFromDeltaOps(List<dynamic> ops) {
    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is! Map) continue;
      final data = op['insert'];
      if (data is String) {
        buffer.write(data);
        if (buffer.length >= previewMaxLength * 2) break;
      }
    }
    final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= previewMaxLength) return text;
    return '${text.substring(0, previewMaxLength).trimRight()}…';
  }
}
