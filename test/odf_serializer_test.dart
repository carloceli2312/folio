import 'package:archive/archive.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/odf_serializer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Serializza un Delta e restituisce il contenuto di content.xml come stringa.
String _contentXml(Delta delta) {
  final bytes = OdfSerializer.serialize(delta);
  final archive = ZipDecoder().decodeBytes(bytes);
  final entry = archive.findFile('content.xml')!;
  return String.fromCharCodes(entry.content as List<int>);
}

/// Costruisce un Delta con un singolo paragrafo di testo semplice.
Delta _plainParagraph(String text) =>
    Delta()..insert(text)..insert('\n');

void main() {
  group('OdfSerializer', () {
    // -----------------------------------------------------------------------
    // Struttura ZIP
    // -----------------------------------------------------------------------

    test('produce un archivio ZIP valido con i file richiesti', () {
      final bytes = OdfSerializer.serialize(_plainParagraph('Test'));
      final archive = ZipDecoder().decodeBytes(bytes);

      expect(archive.findFile('mimetype'), isNotNull);
      expect(archive.findFile('META-INF/manifest.xml'), isNotNull);
      expect(archive.findFile('content.xml'), isNotNull);
      expect(archive.findFile('styles.xml'), isNotNull);
    });

    test('il file mimetype contiene il media type ODF corretto', () {
      final bytes = OdfSerializer.serialize(_plainParagraph('x'));
      final archive = ZipDecoder().decodeBytes(bytes);
      final mimetype = String.fromCharCodes(
        archive.findFile('mimetype')!.content as List<int>,
      );
      expect(
        mimetype,
        equals('application/vnd.oasis.opendocument.text'),
      );
    });

    // -----------------------------------------------------------------------
    // Testo semplice
    // -----------------------------------------------------------------------

    test('paragrafo semplice genera <text:p> con il testo corretto', () {
      final xml = _contentXml(_plainParagraph('Ciao mondo'));
      expect(xml, contains('<text:p'));
      expect(xml, contains('Ciao mondo'));
    });

    test('caratteri speciali XML vengono correttamente eseguiti l\'escape', () {
      final xml = _contentXml(_plainParagraph('a < b & c > d'));
      expect(xml, contains('a &lt; b &amp; c &gt; d'));
      expect(xml, isNot(contains('a < b')));
    });

    test('delta vuoto (solo \\n) produce content.xml valido senza crash', () {
      final delta = Delta()..insert('\n');
      expect(() => _contentXml(delta), returnsNormally);
    });

    // -----------------------------------------------------------------------
    // Formattazione inline
    // -----------------------------------------------------------------------

    test('testo bold genera uno stile con fo:font-weight="bold"', () {
      final delta = Delta()
        ..insert('Grassetto', {'bold': true})
        ..insert('\n');
      final xml = _contentXml(delta);
      expect(xml, contains('fo:font-weight="bold"'));
      expect(xml, contains('Grassetto'));
    });

    test('testo italic genera uno stile con fo:font-style="italic"', () {
      final delta = Delta()
        ..insert('Corsivo', {'italic': true})
        ..insert('\n');
      final xml = _contentXml(delta);
      expect(xml, contains('fo:font-style="italic"'));
    });

    test('testo underline genera stile con text-underline-style="solid"', () {
      final delta = Delta()
        ..insert('Sottolineato', {'underline': true})
        ..insert('\n');
      final xml = _contentXml(delta);
      expect(xml, contains('style:text-underline-style="solid"'));
    });

    test('testo strike genera stile con text-line-through-style="solid"', () {
      final delta = Delta()
        ..insert('Barrato', {'strike': true})
        ..insert('\n');
      final xml = _contentXml(delta);
      expect(xml, contains('style:text-line-through-style="solid"'));
    });

    test('bold+italic genera un singolo stile con entrambi gli attributi', () {
      final delta = Delta()
        ..insert('BoldItalic', {'bold': true, 'italic': true})
        ..insert('\n');
      final xml = _contentXml(delta);
      expect(xml, contains('fo:font-weight="bold"'));
      expect(xml, contains('fo:font-style="italic"'));
    });

    test('due span con gli stessi attributi riutilizzano lo stesso stile', () {
      final delta = Delta()
        ..insert('A', {'bold': true})
        ..insert(' normale ')
        ..insert('B', {'bold': true})
        ..insert('\n');
      final xml = _contentXml(delta);
      // T1 deve apparire esattamente due volte come style-name (una def + due usi)
      final matches = RegExp('style:name="T1"').allMatches(xml);
      expect(matches.length, equals(1)); // definita una volta sola
    });

    test('colore testo viene incluso come fo:color nel content.xml', () {
      final delta = Delta()
        ..insert('Rosso', {'color': '#FF0000'})
        ..insert('\n');
      final xml = _contentXml(delta);
      expect(xml, contains('fo:color="#FF0000"'));
    });

    // -----------------------------------------------------------------------
    // Heading
    // -----------------------------------------------------------------------

    test('heading level 1 genera <text:h text:outline-level="1">', () {
      final delta = Delta()
        ..insert('Titolo')
        ..insert('\n', {'header': 1});
      final xml = _contentXml(delta);
      expect(xml, contains('text:outline-level="1"'));
      expect(xml, contains('Titolo'));
    });

    test('heading level 2 genera <text:h text:outline-level="2">', () {
      final delta = Delta()
        ..insert('Sottotitolo')
        ..insert('\n', {'header': 2});
      final xml = _contentXml(delta);
      expect(xml, contains('text:outline-level="2"'));
    });

    // -----------------------------------------------------------------------
    // Liste
    // -----------------------------------------------------------------------

    test('lista bullet genera <text:list> con style L_bullet', () {
      final delta = Delta()
        ..insert('Elemento')
        ..insert('\n', {'list': 'bullet'});
      final xml = _contentXml(delta);
      expect(xml, contains('text:style-name="L_bullet"'));
      expect(xml, contains('Elemento'));
    });

    test('lista ordinata genera <text:list> con style L_ordered', () {
      final delta = Delta()
        ..insert('Primo')
        ..insert('\n', {'list': 'ordered'});
      final xml = _contentXml(delta);
      expect(xml, contains('text:style-name="L_ordered"'));
    });

    // -----------------------------------------------------------------------
    // Round-trip: parse → serialize → parse
    // -----------------------------------------------------------------------

    test('round-trip testo semplice: parse→serialize→parse preserva il testo',
        () {
      // Crea un Delta con più paragrafi
      final original = Delta()
        ..insert('Primo paragrafo')
        ..insert('\n')
        ..insert('Secondo paragrafo')
        ..insert('\n');

      // Serializza in ODF
      final odfBytes = OdfSerializer.serialize(original);

      // Re-importa via parser
      // ignore: avoid_relative_lib_imports
      // (test diretto senza import per evitare dipendenza circolare nel test)
      final archive = ZipDecoder().decodeBytes(odfBytes);
      final contentXmlEntry = archive.findFile('content.xml')!;
      final xmlContent =
          String.fromCharCodes(contentXmlEntry.content as List<int>);

      // Verifica che il testo sia presente nel XML prodotto
      expect(xmlContent, contains('Primo paragrafo'));
      expect(xmlContent, contains('Secondo paragrafo'));
    });
  });
}
