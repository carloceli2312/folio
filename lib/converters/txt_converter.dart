import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_quill/quill_delta.dart';

import 'converter.dart';

/// Converter bidirezionale per file plain text (`.txt`).
///
/// Import: UTF-8 decode → Delta con un singolo blocco di testo.
/// Export: concatenazione di tutte le stringhe del Delta; newline preservati.
/// Round-trip: nessuna perdita (la formattazione ODF/Quill viene scartata
/// all'export, ma il testo grezzo è identico).
class TxtConverter extends DocumentConverter {
  const TxtConverter();

  @override
  String get extension => 'txt';

  @override
  Delta fromBytes(Uint8List bytes) {
    // Rileva archivi ZIP (firma PK\x03\x04) — accade quando l'utente salva
    // un documento ODF via "Salva" e digita .txt nel dialog anziché usare
    // il menu "Esporta come .txt".
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      throw const ConversionException(
        'Il file sembra un documento ODF, non un testo normale. '
        'Rinominalo in .odt e aprilo con "Apri".',
      );
    }
    // allowMalformed: true sostituisce i byte non decodificabili come UTF-8
    // con U+FFFD — permette di aprire file in encoding legacy (Latin-1,
    // Windows-1252) senza crash.
    final text = utf8.decode(bytes, allowMalformed: true);
    if (text.isEmpty) return Delta()..insert('\n');
    // Rimuove l'eventuale BOM UTF-8 (EF BB BF) che alcuni editor aggiungono.
    final clean = text.startsWith('﻿') ? text.substring(1) : text;
    // Quill richiede che il documento finisca sempre con \n.
    final normalized = clean.endsWith('\n') ? clean : '$clean\n';
    return Delta()..insert(normalized);
  }

  @override
  Uint8List toBytes(Delta delta) {
    final buffer = StringBuffer();
    for (final op in delta.toList()) {
      final data = op.data;
      if (data is String) buffer.write(data);
    }
    // Rimuove l'eventuale \n finale aggiunto da Quill (non fa parte del
    // testo originale e genererebbe una riga vuota in fondo al file).
    var text = buffer.toString();
    if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
    return utf8.encode(text);
  }
}
