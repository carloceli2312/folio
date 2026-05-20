import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_quill/quill_delta.dart';

import 'conversion_exception.dart';
import 'converter.dart';

/// Converter bidirezionale per file plain text (`.txt`).
class TxtConverter extends DocumentConverter {
  const TxtConverter();

  @override
  String get extension => 'txt';

  @override
  Delta fromBytes(Uint8List bytes) {
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
    final text = utf8.decode(bytes, allowMalformed: true);
    if (text.isEmpty) return Delta()..insert('\n');
    final clean = text.startsWith('﻿') ? text.substring(1) : text;
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
    var text = buffer.toString();
    if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
    return utf8.encode(text);
  }
}
