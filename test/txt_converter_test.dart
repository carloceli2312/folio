import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/converters/converter.dart';
import 'package:folio/converters/txt_converter.dart';

void main() {
  const converter = TxtConverter();

  Uint8List bytes(String s) => utf8.encode(s);

  group('TxtConverter.fromBytes', () {
    test('testo semplice → Delta con un unico insert', () {
      final delta = converter.fromBytes(bytes('Ciao mondo'));
      final ops = delta.toList();
      expect(ops, hasLength(1));
      expect(ops.first.data, 'Ciao mondo\n');
    });

    test('testo già terminato con \\n non viene duplicato', () {
      final delta = converter.fromBytes(bytes('Riga\n'));
      expect(delta.toList().first.data, 'Riga\n');
    });

    test('file vuoto → Delta con solo \\n (documento Quill minimo)', () {
      final delta = converter.fromBytes(bytes(''));
      expect(delta.toList().first.data, '\n');
    });

    test('testo multi-riga preserva i newline', () {
      final delta = converter.fromBytes(bytes('Riga 1\nRiga 2\nRiga 3'));
      expect(delta.toList().first.data, 'Riga 1\nRiga 2\nRiga 3\n');
    });

    test('bytes non UTF-8 (Latin-1) → apertura senza crash, U+FFFD per i byte invalidi', () {
      final latin1Bytes = Uint8List.fromList([0xC8, 0xE0, 0xF9]); // È à ù in Latin-1
      expect(() => converter.fromBytes(latin1Bytes), returnsNormally);
      final delta = converter.fromBytes(latin1Bytes);
      expect(delta.toList(), isNotEmpty);
    });

    test('archivio ZIP (firma PK) → ConversionException con messaggio chiaro', () {
      // Simula un ODT salvato con estensione .txt
      final zipBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]);
      expect(
        () => converter.fromBytes(zipBytes),
        throwsA(
          isA<ConversionException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('.odt'),
          ),
        ),
      );
    });
  });

  group('TxtConverter.toBytes', () {
    test('Delta semplice → testo senza \\n finale', () {
      final delta = converter.fromBytes(bytes('Ciao'));
      final out = utf8.decode(converter.toBytes(delta));
      expect(out, 'Ciao');
    });

    test('Delta multi-riga → newline interni preservati', () {
      final delta = converter.fromBytes(bytes('A\nB\nC'));
      final out = utf8.decode(converter.toBytes(delta));
      expect(out, 'A\nB\nC');
    });
  });

  group('TxtConverter — round-trip', () {
    test('testo → Delta → testo = identico', () {
      const original = 'Prima riga\nSeconda riga\nTerza riga';
      final delta = converter.fromBytes(bytes(original));
      final result = utf8.decode(converter.toBytes(delta));
      expect(result, original);
    });

    test('testo con caratteri accentati → round-trip corretto', () {
      const original = 'Città, caffè, perché, è, à, ù';
      final delta = converter.fromBytes(bytes(original));
      final result = utf8.decode(converter.toBytes(delta));
      expect(result, original);
    });
  });
}
