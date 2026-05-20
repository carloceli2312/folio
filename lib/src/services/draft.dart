/// Una bozza non salvata: snapshot del contenuto dell'editor in un certo
/// istante, persistito su storage app-private.
class Draft {
  const Draft({
    required this.fileName,
    required this.deltaOps,
    required this.savedAt,
    this.savedPath,
  });

  /// Nome file proposto al prossimo "Save As" (titolo correlato).
  final String fileName;

  /// Delta serializzato come JSON (lista di operazioni).
  final List<dynamic> deltaOps;

  /// Quando la bozza è stata persistita.
  final DateTime savedAt;

  /// Path locale del documento da cui nasce la bozza, se esisteva già un
  /// file salvato (es. bozza di un recente). `null` per una bozza di un
  /// documento nuovo mai salvato: in quel caso la ripresa passa per
  /// "Salva con nome".
  final String? savedPath;

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'deltaOps': deltaOps,
    'savedAt': savedAt.toIso8601String(),
    if (savedPath != null) 'savedPath': savedPath,
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
    final path = json['savedPath'];
    return Draft(
      fileName: fileName,
      deltaOps: ops,
      savedAt: parsed,
      savedPath: path is String ? path : null,
    );
  }
}
