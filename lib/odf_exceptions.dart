/// Typed exceptions raised by [OdfParser] / [OdfSerializer].
///
/// L'UI cattura queste eccezioni e mostra il [userMessage] all'utente,
/// preservando [cause] per logging/crash reporting.
sealed class OdfException implements Exception {
  const OdfException(this.userMessage, [this.cause]);

  /// Messaggio in italiano, già pronto per essere mostrato in SnackBar/dialog.
  final String userMessage;

  /// Eccezione originale (se presente). Usata solo per log, non per la UI.
  final Object? cause;

  @override
  String toString() =>
      cause == null ? userMessage : '$userMessage (causa: $cause)';
}

/// Il file non è un archivio ZIP valido (o è troncato/corrotto).
class OdfInvalidArchiveException extends OdfException {
  const OdfInvalidArchiveException([Object? cause])
      : super(
          'Il file non sembra essere un documento .odt valido.',
          cause,
        );
}

/// L'archivio ZIP non contiene `content.xml`.
class OdfMissingContentException extends OdfException {
  const OdfMissingContentException()
      : super('Il documento è incompleto: manca content.xml.');
}

/// `content.xml` esiste ma non è XML ben formato o non rispetta lo schema ODF.
class OdfMalformedXmlException extends OdfException {
  const OdfMalformedXmlException([Object? cause])
      : super('Il contenuto del documento è danneggiato.', cause);
}

/// Errore generico non classificabile durante parsing/serializzazione.
class OdfUnknownException extends OdfException {
  const OdfUnknownException([Object? cause])
      : super('Errore imprevisto durante l\'elaborazione del documento.', cause);
}
