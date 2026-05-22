import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/folio.dart';

/// Costruisce uno ZIP in memoria con i file forniti.
Uint8List _zipWith(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('OdfParser.parse — input malformati', () {
    test('byte vuoti → OdfInvalidArchiveException', () {
      expect(
        () => OdfParser.parse(Uint8List(0)),
        throwsA(isA<OdfInvalidArchiveException>()),
      );
    });

    test('byte casuali (non-ZIP) → OdfException', () {
      // ZipDecoder è permissivo: con input casuali può restituire un archivio
      // vuoto invece di lanciare. In quel caso scatta la mancanza di
      // content.xml — entrambi i casi sono accettabili (sono OdfException).
      final garbage = Uint8List.fromList(
        List<int>.generate(128, (i) => (i * 7) & 0xFF),
      );
      expect(() => OdfParser.parse(garbage), throwsA(isA<OdfException>()));
    });

    test('ZIP senza content.xml → OdfMissingContentException', () {
      final bytes = _zipWith({
        'mimetype': 'application/vnd.oasis.opendocument.text',
      });
      expect(
        () => OdfParser.parse(bytes),
        throwsA(isA<OdfMissingContentException>()),
      );
    });

    test('content.xml con XML malformato → OdfMalformedXmlException', () {
      final bytes = _zipWith({
        'content.xml': '<office:document-content><not-closed>',
      });
      expect(
        () => OdfParser.parse(bytes),
        throwsA(isA<OdfMalformedXmlException>()),
      );
    });

    test('OdfException classifica l\'errore tramite il tipo sealed', () {
      try {
        OdfParser.parse(Uint8List(0));
        fail('expected exception');
      } on OdfException catch (e) {
        // Opzione A: il domain non porta più un messaggio localizzato; la
        // classificazione avviene tramite il tipo sealed e il messaggio
        // utente viene risolto nello strato UI.
        expect(e, isA<OdfInvalidArchiveException>());
        expect(e.toString(), isNotEmpty);
      }
    });
  });

  group('OdfParser.parseContentXml — input malformati', () {
    test('XML non ben formato → OdfMalformedXmlException', () {
      expect(
        () => OdfParser.parseContentXml('<not><closed>'),
        throwsA(isA<OdfMalformedXmlException>()),
      );
    });

    test('stringa vuota → OdfMalformedXmlException', () {
      expect(
        () => OdfParser.parseContentXml(''),
        throwsA(isA<OdfMalformedXmlException>()),
      );
    });
  });
}
