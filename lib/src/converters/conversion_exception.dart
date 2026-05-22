/// Locale-agnostic categories of document converter (.txt / .md) failures.
///
/// The UI layer maps each kind to a localized, user-facing message.
enum ConversionErrorKind {
  /// The file bytes are not valid UTF-8 text.
  notValidUtf8,

  /// The Markdown source could not be converted to a document.
  markdownConversionFailed,

  /// A plain-text import was given what looks like an ODF (.odt) file.
  odfFileNotPlainText,
}

/// Typed exception for document converter failures.
///
/// Carries a locale-agnostic [kind]; the UI layer turns it into a
/// localized, user-facing message.
class ConversionException implements Exception {
  const ConversionException(this.kind, [this.cause]);

  /// Locale-agnostic category of the failure.
  final ConversionErrorKind kind;

  /// Original exception (if any). Used only for logging, never for the UI.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ConversionException(${kind.name})'
      : 'ConversionException(${kind.name}, cause: $cause)';
}
