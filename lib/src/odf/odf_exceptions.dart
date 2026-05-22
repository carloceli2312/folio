/// Typed exceptions raised by [OdfParser] / [OdfSerializer].
///
/// The hierarchy is `sealed`: each subtype is a locale-agnostic error code.
/// The UI layer is responsible for turning the runtime type into a
/// localized, user-facing message.
sealed class OdfException implements Exception {
  const OdfException([this.cause]);

  /// Original exception (if any). Used only for logging, never for the UI.
  final Object? cause;

  @override
  String toString() =>
      cause == null ? '$runtimeType' : '$runtimeType (cause: $cause)';
}

/// The file is not a valid ZIP archive (or is truncated/corrupted).
class OdfInvalidArchiveException extends OdfException {
  const OdfInvalidArchiveException([super.cause]);
}

/// The ZIP archive does not contain `content.xml`.
class OdfMissingContentException extends OdfException {
  const OdfMissingContentException();
}

/// `content.xml` exists but is not well-formed XML or violates the ODF schema.
class OdfMalformedXmlException extends OdfException {
  const OdfMalformedXmlException([super.cause]);
}

/// Generic unclassified failure during parsing/serialization.
class OdfUnknownException extends OdfException {
  const OdfUnknownException([super.cause]);
}
