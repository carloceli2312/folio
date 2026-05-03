import 'dart:typed_data';

import 'package:flutter_quill/quill_delta.dart';

/// Contratto comune per tutti i converter di formato documento.
///
/// Ogni implementazione lavora su [Delta] (formato interno di Folio) e
/// gira su isolate via `compute()` — le implementazioni devono essere
/// funzioni statiche o top-level per essere compatibili.
abstract class DocumentConverter {
  const DocumentConverter();

  /// Estensione del formato gestito (senza punto, es. `'md'`).
  String get extension;

  /// Converte [bytes] nel formato sorgente in un [Delta] Quill.
  ///
  /// Lancia [ConversionException] in caso di input non valido o non
  /// supportato.
  Delta fromBytes(Uint8List bytes);

  /// Serializza [delta] nel formato target e restituisce i bytes.
  Uint8List toBytes(Delta delta);
}

/// Eccezione tipizzata per errori di conversione.
class ConversionException implements Exception {
  const ConversionException(this.userMessage, [this.cause]);

  final String userMessage;
  final Object? cause;

  @override
  String toString() => 'ConversionException: $userMessage'
      '${cause != null ? ' (causa: $cause)' : ''}';
}
