/// Eccezione tipizzata per errori di conversione.
class ConversionException implements Exception {
  const ConversionException(this.userMessage, [this.cause]);

  final String userMessage;
  final Object? cause;

  @override
  String toString() =>
      'ConversionException: $userMessage'
      '${cause != null ? ' (causa: $cause)' : ''}';
}
