import 'dart:typed_data';

import 'package:flutter_quill/quill_delta.dart';

/// Contratto comune per tutti i converter di formato documento.
abstract class DocumentConverter {
  const DocumentConverter();

  /// Estensione del formato gestito (senza punto, es. `'md'`).
  String get extension;

  /// Converte [bytes] nel formato sorgente in un [Delta] Quill.
  Delta fromBytes(Uint8List bytes);

  /// Serializza [delta] nel formato target e restituisce i bytes.
  Uint8List toBytes(Delta delta);
}
