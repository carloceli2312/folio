/// Una voce nella lista dei documenti recenti.
class RecentFile {
  const RecentFile({
    required this.name,
    required this.preview,
    required this.openedAt,
    this.cachedPath,
    this.userPath,
  });

  /// Nome file (es. `documento.odt`).
  final String name;

  /// Anteprima testuale del documento (max ~120 char).
  final String preview;

  /// Quando il file è stato aperto/salvato l'ultima volta.
  final DateTime openedAt;

  /// Path locale (in storage app-private) della copia binaria, se presente.
  /// `null` per voci legacy create prima dell'introduzione della cache.
  final String? cachedPath;

  /// Path del file utente "vero" (es. `<external>/Folio/nome.odt`), scelto
  /// dall'utente in Save As: è qui che il "Salva" sovrascrive/rinomina.
  /// `null` per voci legacy create prima della separazione user/cache:
  /// in quel caso il "Salva" dell'editor ridirige a "Salva con nome".
  /// La [cachedPath] resta una copia binaria interna per riapertura
  /// istantanea (i path utente non sempre sono accessibili in lettura
  /// fra sessioni, su SAF).
  final String? userPath;

  Map<String, dynamic> toJson() => {
    'name': name,
    'preview': preview,
    'openedAt': openedAt.toIso8601String(),
    if (cachedPath != null) 'cachedPath': cachedPath,
    if (userPath != null) 'userPath': userPath,
  };

  static RecentFile? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final openedAt = json['openedAt'];
    if (name is! String || openedAt is! String) return null;
    final parsed = DateTime.tryParse(openedAt);
    if (parsed == null) return null;
    return RecentFile(
      name: name,
      preview: (json['preview'] as String?) ?? '',
      openedAt: parsed,
      cachedPath: json['cachedPath'] as String?,
      userPath: json['userPath'] as String?,
    );
  }
}
