import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/folio.dart';

import 'odt_fixtures.dart';

/// Concatena le insert di tipo stringa in un singolo `String` (utile per
/// asserire la presenza di testo a prescindere dalla struttura del Delta).
String _allText(Delta delta) {
  final buffer = StringBuffer();
  for (final op in delta.toList()) {
    final data = op.data;
    if (data is String) buffer.write(data);
  }
  return buffer.toString();
}

/// Restituisce le operations che inseriscono `\n` con uno specifico set di
/// attributi (utile per controllare list / heading attributes).
Iterable<Operation> _newlineOpsWith(Delta delta, String attribute) {
  return delta.toList().where(
    (op) => op.data == '\n' && (op.attributes?[attribute] != null),
  );
}

void main() {
  group('Integrazione: parse(Uint8List) su ODT realistici', () {
    test('plainText: estrae il testo dal ZIP', () {
      final delta = OdfParser.parse(OdtFixtures.plainText());
      expect(_allText(delta), contains('Hello world'));
    });

    test('formattedDocument: heading + bold + italic preservati', () {
      final delta = OdfParser.parse(OdtFixtures.formattedDocument());
      final text = _allText(delta);
      expect(text, contains('Titolo principale'));
      expect(text, contains('grassetto'));
      expect(text, contains('corsivo'));

      // Heading H1 → newline con attribute 'header': 1
      final headerOps = _newlineOpsWith(delta, 'header');
      expect(headerOps, isNotEmpty);
      expect(headerOps.first.attributes!['header'], 1);

      // Almeno un'operazione bold e una italic
      final ops = delta.toList();
      expect(
        ops.any((op) => op.attributes?['bold'] == true),
        isTrue,
        reason: 'Atteso almeno un run con bold=true',
      );
      expect(
        ops.any((op) => op.attributes?['italic'] == true),
        isTrue,
        reason: 'Atteso almeno un run con italic=true',
      );
    });

    test('documentWithLists: bullet e ordered distinti', () {
      final delta = OdfParser.parse(OdtFixtures.documentWithLists());
      final text = _allText(delta);
      expect(text, contains('Mela'));
      expect(text, contains('Pera'));
      expect(text, contains('Primo'));
      expect(text, contains('Secondo'));

      final listOps = _newlineOpsWith(delta, 'list').toList();
      final values = listOps.map((op) => op.attributes!['list']).toSet();
      expect(values, containsAll(<String>['bullet', 'ordered']));
    });

    test('documentWithImage: l\'immagine viene estratta come embed', () {
      final delta = OdfParser.parse(OdtFixtures.documentWithImage());
      final text = _allText(delta);
      expect(text, contains('Prima dell\'immagine'));
      expect(text, contains('Dopo l\'immagine'));

      // L'embed dell'immagine è inserito come Map<String, dynamic>
      final imageOps = delta.toList().where((op) {
        final data = op.data;
        return data is Map && data['image'] is String;
      }).toList();
      expect(imageOps, hasLength(1));
      final dataUri = (imageOps.first.data as Map)['image'] as String;
      expect(dataUri, startsWith('data:image/png;base64,'));
      // Niente fallback testuale [immagine] quando l'archivio è disponibile.
      expect(text, isNot(contains('[immagine]')));
    });
  });

  group('Integrazione: round-trip parse → serialize → parse', () {
    test('plainText: il testo sopravvive al round-trip', () {
      final originalDelta = OdfParser.parse(OdtFixtures.plainText());
      final reSerialized = OdfSerializer.serialize(originalDelta);
      final reparsed = OdfParser.parse(reSerialized);
      expect(_allText(reparsed), contains('Hello world'));
    });

    test('formattedDocument: bold + italic + heading sopravvivono', () {
      final originalDelta = OdfParser.parse(OdtFixtures.formattedDocument());
      final reSerialized = OdfSerializer.serialize(originalDelta);
      final reparsed = OdfParser.parse(reSerialized);

      final text = _allText(reparsed);
      expect(text, contains('Titolo principale'));
      expect(text, contains('grassetto'));
      expect(text, contains('corsivo'));

      final ops = reparsed.toList();
      expect(ops.any((op) => op.attributes?['bold'] == true), isTrue);
      expect(ops.any((op) => op.attributes?['italic'] == true), isTrue);
      expect(_newlineOpsWith(reparsed, 'header'), isNotEmpty);
    });

    test('documentWithLists: bullet/ordered sopravvivono', () {
      final originalDelta = OdfParser.parse(OdtFixtures.documentWithLists());
      final reSerialized = OdfSerializer.serialize(originalDelta);
      final reparsed = OdfParser.parse(reSerialized);

      final values = _newlineOpsWith(
        reparsed,
        'list',
      ).map((op) => op.attributes!['list']).toSet();
      expect(values, containsAll(<String>['bullet', 'ordered']));
    });
  });
}
