import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/odf_exceptions.dart';
import 'package:folio/odf_parser.dart';

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
      expect(
        () => OdfParser.parse(garbage),
        throwsA(isA<OdfException>()),
      );
    });

    test('ZIP senza content.xml → OdfMissingContentException', () {
      final bytes = _zipWith({'mimetype': 'application/vnd.oasis.opendocument.text'});
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

    test('messaggio utente è in italiano e non espone i dettagli interni', () {
      try {
        OdfParser.parse(Uint8List(0));
        fail('expected exception');
      } on OdfException catch (e) {
        expect(e.userMessage, isNotEmpty);
        expect(e.userMessage, isNot(contains('Exception')));
        expect(e.userMessage, isNot(contains('Archive')));
        expect(e.userMessage, isNot(contains('XmlParser')));
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
