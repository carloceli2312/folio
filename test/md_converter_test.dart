import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/folio.dart';

void main() {
  const converter = MdConverter();

  Uint8List bytes(String s) => utf8.encode(s);
  String md(String s) =>
      utf8.decode(converter.toBytes(converter.fromBytes(bytes(s))));

  group('MdConverter.fromBytes — import', () {
    test('paragrafo semplice → insert di testo + \\n', () {
      final delta = converter.fromBytes(bytes('Ciao mondo'));
      final allText = delta
          .toList()
          .where((o) => o.data is String)
          .map((o) => o.data as String)
          .join();
      expect(allText, contains('Ciao mondo'));
    });

    test('heading H1 → attributo header:1 sul \\n di chiusura', () {
      final delta = converter.fromBytes(bytes('# Titolo'));
      final ops = delta.toList();
      final nl = ops.firstWhere((o) => o.data == '\n');
      expect(nl.attributes?['header'], 1);
    });

    test('heading H2 → header:2', () {
      final delta = converter.fromBytes(bytes('## Sottotitolo'));
      final ops = delta.toList();
      final nl = ops.firstWhere((o) => o.data == '\n');
      expect(nl.attributes?['header'], 2);
    });

    test('testo bold (**) → attributo bold:true', () {
      final delta = converter.fromBytes(bytes('**grassetto**'));
      final ops = delta.toList();
      final bold = ops.where((o) => o.attributes?['bold'] == true);
      expect(bold, isNotEmpty);
    });

    test('testo italic (*) → attributo italic:true', () {
      final delta = converter.fromBytes(bytes('*corsivo*'));
      final ops = delta.toList();
      final italic = ops.where((o) => o.attributes?['italic'] == true);
      expect(italic, isNotEmpty);
    });

    test('lista puntata → list:bullet sul \\n di ogni item', () {
      final delta = converter.fromBytes(bytes('- Voce A\n- Voce B'));
      final ops = delta.toList();
      final bullets = ops.where((o) => o.attributes?['list'] == 'bullet');
      expect(bullets.length, greaterThanOrEqualTo(2));
    });

    test('lista numerata → list:ordered', () {
      final delta = converter.fromBytes(bytes('1. Primo\n2. Secondo'));
      final ops = delta.toList();
      final ordered = ops.where((o) => o.attributes?['list'] == 'ordered');
      expect(ordered.length, greaterThanOrEqualTo(2));
    });

    test('inline code → attributo code:true', () {
      final delta = converter.fromBytes(bytes('Usa `print()` qui'));
      final ops = delta.toList();
      expect(ops.any((o) => o.attributes?['code'] == true), isTrue);
    });

    test('bytes non UTF-8 → ConversionException', () {
      final bad = Uint8List.fromList([0xFF, 0xFE, 0x00]);
      expect(
        () => converter.fromBytes(bad),
        throwsA(isA<ConversionException>()),
      );
    });

    test('documento vuoto → Delta non vuoto (almeno \\n Quill)', () {
      final delta = converter.fromBytes(bytes(''));
      expect(delta.toList(), isNotEmpty);
    });
  });

  group('MdConverter.toBytes — export', () {
    test('paragrafo → riga di testo in output', () {
      final out = md('Paragrafo semplice');
      expect(out, contains('Paragrafo semplice'));
    });

    test('heading H1 → riga con #', () {
      final out = md('# Titolo');
      expect(out, contains('# Titolo'));
    });

    test('heading H2 → ##', () {
      final out = md('## Sub');
      expect(out, contains('## Sub'));
    });

    test('lista puntata → righe con "-"', () {
      final out = md('- A\n- B');
      expect(out, contains('- '));
    });

    test('lista numerata → righe con "1."', () {
      final out = md('1. Primo\n2. Secondo');
      expect(out, contains('1. '));
    });

    test('bold → **testo**', () {
      final out = md('**bold**');
      expect(out, contains('**'));
    });

    test('italic → _testo_', () {
      final out = md('*italic*');
      expect(out, contains('_'));
    });
  });

  group('MdConverter — round-trip', () {
    test('heading + paragrafo → testo stabile dopo MD→Delta→MD', () {
      const source = '# Titolo\n\nQuesto è un paragrafo.';
      final out = md(source);
      expect(out, contains('# Titolo'));
      expect(out, contains('Questo è un paragrafo.'));
    });

    test('lista puntata → round-trip stabile', () {
      const source = '- Alpha\n- Beta\n- Gamma';
      final out = md(source);
      expect(out, contains('Alpha'));
      expect(out, contains('Beta'));
      expect(out, contains('Gamma'));
    });
  });
}
