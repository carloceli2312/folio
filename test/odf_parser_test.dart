import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/odf_parser.dart';

// ---------------------------------------------------------------------------
// Minimal ODF content.xml fixtures
// ---------------------------------------------------------------------------

/// The ODF namespaces that every content.xml must declare.
const _nsdecl = '''
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
  xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
  xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
  xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
''';

/// Wraps arbitrary body content in a minimal but well-formed content.xml
/// document.
String _wrapBody(String bodyXml, {String autoStyles = ''}) => '''
<?xml version="1.0" encoding="UTF-8"?>
<office:document-content $_nsdecl>
  <office:automatic-styles>$autoStyles</office:automatic-styles>
  <office:body>
    <office:text>
      $bodyXml
    </office:text>
  </office:body>
</office:document-content>
''';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns the list of [Operation]s from a [Delta], filtering out any
/// trailing-only newline that was added to ensure the document is not empty.
List<Operation> _ops(Delta delta) => delta.toList();

void main() {
  group('OdfParser.parseContentXml', () {
    // -----------------------------------------------------------------------
    // Plain text
    // -----------------------------------------------------------------------

    test('plain paragraph produces a text insert followed by \\n', () {
      final xml = _wrapBody('<text:p>Hello world</text:p>');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // quill_delta v3 merges adjacent inserts with the same attributes,
      // so "Hello world" and "\n" (both null-attrs) may appear as one op.
      final text = ops.map((o) => o.data).join();
      expect(text, 'Hello world\n');
      expect(ops.every((o) => o.attributes == null), isTrue);
    });

    test('multiple paragraphs each end with \\n', () {
      final xml = _wrapBody('''
        <text:p>First</text:p>
        <text:p>Second</text:p>
      ''');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // quill_delta v3 merges adjacent null-attrs ops, so both paragraphs
      // may be collapsed into one op "First\nSecond\n".
      final text = ops.map((o) => o.data).join();
      expect(text, 'First\nSecond\n');
    });

    test('empty document returns a single \\n', () {
      final xml = _wrapBody('');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops, hasLength(1));
      expect(ops[0].data, '\n');
    });

    // -----------------------------------------------------------------------
    // Heading
    // -----------------------------------------------------------------------

    test('heading element carries header attribute on its \\n', () {
      final xml = _wrapBody(
        '<text:h text:outline-level="1">My Title</text:h>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops, hasLength(2));
      expect(ops[0].data, 'My Title');
      expect(ops[0].attributes, isNull);
      expect(ops[1].data, '\n');
      expect(ops[1].attributes, containsPair('header', 1));
    });

    test('heading level 2 sets header:2', () {
      final xml = _wrapBody(
        '<text:h text:outline-level="2">Sub</text:h>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops.last.attributes, containsPair('header', 2));
    });

    test('heading without outline-level defaults to 1', () {
      final xml = _wrapBody('<text:h>Title</text:h>');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops.last.attributes, containsPair('header', 1));
    });

    // -----------------------------------------------------------------------
    // Inline formatting via <text:span>
    // -----------------------------------------------------------------------

    test('bold span carries bold attribute', () {
      const autoStyles = '''
        <style:style style:name="T1" style:family="text">
          <style:text-properties fo:font-weight="bold"/>
        </style:style>
      ''';
      final xml = _wrapBody(
        '<text:p>Normal <text:span text:style-name="T1">Bold</text:span> text</text:p>',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // ops: "Normal " | "Bold"(bold) | " text\n"
      // (" text" and "\n" are both null-attrs, so quill_delta v3 merges them)
      expect(ops, hasLength(3));
      expect(ops[0].data, 'Normal ');
      expect(ops[0].attributes, isNull);
      expect(ops[1].data, 'Bold');
      expect(ops[1].attributes, containsPair('bold', true));
      expect(ops[2].data, ' text\n');
      expect(ops[2].attributes, isNull);
    });

    test('italic span carries italic attribute', () {
      const autoStyles = '''
        <style:style style:name="T2" style:family="text">
          <style:text-properties fo:font-style="italic"/>
        </style:style>
      ''';
      final xml = _wrapBody(
        '<text:p><text:span text:style-name="T2">Italic</text:span></text:p>',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[0].attributes, containsPair('italic', true));
    });

    test('underline span carries underline attribute', () {
      const autoStyles = '''
        <style:style style:name="T3" style:family="text">
          <style:text-properties style:text-underline-style="solid"/>
        </style:style>
      ''';
      final xml = _wrapBody(
        '<text:p><text:span text:style-name="T3">Underline</text:span></text:p>',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[0].attributes, containsPair('underline', true));
    });

    test('strike-through span carries strike attribute', () {
      const autoStyles = '''
        <style:style style:name="T4" style:family="text">
          <style:text-properties style:text-line-through-style="solid"/>
        </style:style>
      ''';
      final xml = _wrapBody(
        '<text:p><text:span text:style-name="T4">Strike</text:span></text:p>',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[0].attributes, containsPair('strike', true));
    });

    test('bold+italic span carries both attributes', () {
      const autoStyles = '''
        <style:style style:name="T5" style:family="text">
          <style:text-properties fo:font-weight="bold" fo:font-style="italic"/>
        </style:style>
      ''';
      final xml = _wrapBody(
        '<text:p><text:span text:style-name="T5">BoldItalic</text:span></text:p>',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[0].attributes, containsPair('bold', true));
      expect(ops[0].attributes, containsPair('italic', true));
    });

    test('unknown style-name produces no formatting attributes', () {
      final xml = _wrapBody(
        '<text:p><text:span text:style-name="Unknown">Text</text:span></text:p>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // "Text" and "\n" are both null-attrs → merged into "Text\n" by quill_delta v3.
      expect(ops[0].data.toString(), startsWith('Text'));
      expect(ops[0].attributes, isNull);
    });

    // -----------------------------------------------------------------------
    // Special inline elements
    // -----------------------------------------------------------------------

    test('<text:line-break/> inserts a newline inside the paragraph', () {
      final xml = _wrapBody(
        '<text:p>Line 1<text:line-break/>Line 2</text:p>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // All null-attrs ops are merged by quill_delta v3; check content as text.
      final text = ops.map((o) => o.data).join();
      expect(text, 'Line 1\nLine 2\n');
    });

    test('<text:tab/> inserts a tab character', () {
      final xml = _wrapBody('<text:p>A<text:tab/>B</text:p>');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // quill_delta v3 merges null-attrs ops → check full text content.
      final text = ops.map((o) => o.data).join();
      expect(text, contains('\t'));
    });

    test('<text:s text:c="3"/> inserts three spaces', () {
      final xml = _wrapBody(
        '<text:p>A<text:s text:c="3"/>B</text:p>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      final text = ops.map((o) => o.data).join();
      expect(text, contains('   '));
    });

    test('<text:s/> without c attribute inserts one space', () {
      final xml = _wrapBody('<text:p>A<text:s/>B</text:p>');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      final text = ops.map((o) => o.data).join();
      expect(text, contains(' '));
    });

    // -----------------------------------------------------------------------
    // Lists
    // -----------------------------------------------------------------------

    test('unordered list items become bullet paragraphs', () {
      final xml = _wrapBody('''
        <text:list>
          <text:list-item><text:p>Item 1</text:p></text:list-item>
          <text:list-item><text:p>Item 2</text:p></text:list-item>
        </text:list>
      ''');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // Item 1, \n(bullet), Item 2, \n(bullet)
      expect(ops, hasLength(4));
      expect(ops[0].data, 'Item 1');
      expect(ops[1].data, '\n');
      expect(ops[1].attributes, containsPair('list', 'bullet'));
      expect(ops[2].data, 'Item 2');
      expect(ops[3].data, '\n');
      expect(ops[3].attributes, containsPair('list', 'bullet'));
    });

    test('ordered list items carry list:ordered attribute', () {
      const autoStyles = '''
        <text:list-style style:name="L1">
          <text:list-level-style-number text:level="1" text:start-value="1" style:num-format="1"/>
        </text:list-style>
      ''';
      final xml = _wrapBody(
        '''
        <text:list text:style-name="L1">
          <text:list-item><text:p>First</text:p></text:list-item>
          <text:list-item><text:p>Second</text:p></text:list-item>
        </text:list>
        ''',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      // First, \n(ordered), Second, \n(ordered)
      expect(ops, hasLength(4));
      expect(ops[1].attributes, containsPair('list', 'ordered'));
      expect(ops[3].attributes, containsPair('list', 'ordered'));
    });

    test('bullet list with explicit style-name stays bullet', () {
      const autoStyles = '''
        <text:list-style style:name="L2">
          <text:list-level-style-bullet text:level="1" text:bullet-char="•"/>
        </text:list-style>
      ''';
      final xml = _wrapBody(
        '''
        <text:list text:style-name="L2">
          <text:list-item><text:p>Alpha</text:p></text:list-item>
        </text:list>
        ''',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[1].attributes, containsPair('list', 'bullet'));
    });

    test('list without style-name defaults to bullet', () {
      final xml = _wrapBody('''
        <text:list>
          <text:list-item><text:p>Solo</text:p></text:list-item>
        </text:list>
      ''');
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[1].attributes, containsPair('list', 'bullet'));
    });

    // -----------------------------------------------------------------------
    // Hyperlink (<text:a>)
    // -----------------------------------------------------------------------

    test('hyperlink senza href: testo incluso senza attributi', () {
      final xml = _wrapBody(
        '<text:p><text:a>Click here</text:a></text:p>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      final text = ops.map((o) => o.data).join();
      expect(text, startsWith('Click here'));
      expect(ops.every((o) => o.attributes == null), isTrue);
    });

    test('hyperlink con xlink:href porta attributo link nel delta', () {
      final xml = _wrapBody(
        '<text:p>'
        '<text:a xlink:href="https://example.com">Visit</text:a>'
        '</text:p>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      final linkOp = ops.firstWhere((o) => o.data == 'Visit');
      expect(linkOp.attributes, containsPair('link', 'https://example.com'));
    });

    test('hyperlink con href vuoto: testo senza attributo link', () {
      final xml = _wrapBody(
        '<text:p><text:a xlink:href="">Testo</text:a></text:p>',
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      final text = ops.map((o) => o.data).join();
      expect(text, startsWith('Testo'));
      // href vuoto → nessun attributo link
      final linkOp = ops.firstWhere(
        (o) => o.data.toString().startsWith('Testo'),
        orElse: () => ops.first,
      );
      expect(linkOp.attributes?['link'], isNull);
    });

    // -----------------------------------------------------------------------
    // Stili avanzati: colore e dimensione font
    // -----------------------------------------------------------------------

    test('colore testo viene incluso come attributo color nel delta', () {
      const autoStyles = '''
        <style:style style:name="C1" style:family="text">
          <style:text-properties fo:color="#FF0000"/>
        </style:style>
      ''';
      final xml = _wrapBody(
        '<text:p><text:span text:style-name="C1">Rosso</text:span></text:p>',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[0].attributes, containsPair('color', '#FF0000'));
    });

    test('dimensione font viene inclusa come attributo size nel delta', () {
      const autoStyles = '''
        <style:style style:name="S1" style:family="text">
          <style:text-properties fo:font-size="18pt"/>
        </style:style>
      ''';
      final xml = _wrapBody(
        '<text:p><text:span text:style-name="S1">Grande</text:span></text:p>',
        autoStyles: autoStyles,
      );
      final delta = OdfParser.parseContentXml(xml);
      final ops = _ops(delta);

      expect(ops[0].attributes, containsPair('size', '18pt'));
    });

    // -----------------------------------------------------------------------
    // Tabelle
    // -----------------------------------------------------------------------

    test('tabella semplice: le celle sono separate da " | "', () {
      final xml = _wrapBody('''
        <table:table>
          <table:table-row>
            <table:table-cell><text:p>A</text:p></table:table-cell>
            <table:table-cell><text:p>B</text:p></table:table-cell>
          </table:table-row>
          <table:table-row>
            <table:table-cell><text:p>C</text:p></table:table-cell>
            <table:table-cell><text:p>D</text:p></table:table-cell>
          </table:table-row>
        </table:table>
      ''');
      final delta = OdfParser.parseContentXml(xml);
      final text = _ops(delta).map((o) => o.data).join();

      // Prima riga intestazione
      expect(text, contains('A | B'));
      // Seconda riga dati
      expect(text, contains('C | D'));
    });

    test('tabella con una sola cella non crasha', () {
      final xml = _wrapBody('''
        <table:table>
          <table:table-row>
            <table:table-cell><text:p>Solo</text:p></table:table-cell>
          </table:table-row>
        </table:table>
      ''');
      expect(() => OdfParser.parseContentXml(xml), returnsNormally);
    });

    test('tabella vuota non crasha', () {
      final xml = _wrapBody('<table:table></table:table>');
      expect(() => OdfParser.parseContentXml(xml), returnsNormally);
    });

    // -----------------------------------------------------------------------
    // Immagini (senza archivio ZIP → placeholder)
    // -----------------------------------------------------------------------

    test('draw:frame senza archivio inserisce placeholder [immagine]', () {
      final xml = _wrapBody('''
        <text:p>
          <draw:frame>
            <draw:image xlink:href="Pictures/foto.png"/>
          </draw:frame>
        </text:p>
      ''');
      final delta = OdfParser.parseContentXml(xml);
      final text = _ops(delta).map((o) => o.data).join();
      expect(text, contains('[immagine]'));
    });

    test('draw:frame senza draw:image non crasha', () {
      final xml = _wrapBody('''
        <text:p>
          <draw:frame>
          </draw:frame>
        </text:p>
      ''');
      expect(() => OdfParser.parseContentXml(xml), returnsNormally);
    });
  });
}
