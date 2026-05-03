import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builder di file `.odt` realistici per i test di integrazione.
///
/// Le fixture sono costruite usando strutture XML che LibreOffice produce
/// davvero (namespace declarations completi, `META-INF/manifest.xml`,
/// `mimetype` come primo file STORED non compresso, ecc.) — l'obiettivo è
/// esercitare l'intero pipeline `OdfParser.parse(Uint8List)` con dati
/// rappresentativi, non solo `parseContentXml(String)`.
class OdtFixtures {
  const OdtFixtures._();

  /// Documento minimale: un paragrafo di testo semplice.
  static Uint8List plainText() => _buildOdt(
        contentBody: '<text:p text:style-name="P1">Hello world</text:p>',
        autoStyles: '',
      );

  /// Documento con grassetto, corsivo e heading H1.
  /// Replica gli stili automatici come sono nominati da LibreOffice
  /// (T1, T2... per text styles, H1... per heading).
  static Uint8List formattedDocument() => _buildOdt(
        contentBody: '''
<text:h text:style-name="P_h1" text:outline-level="1">Titolo principale</text:h>
<text:p text:style-name="P1">Questo è <text:span text:style-name="T1">grassetto</text:span> e questo è <text:span text:style-name="T2">corsivo</text:span>.</text:p>
''',
        autoStyles: '''
<style:style style:name="T1" style:family="text">
  <style:text-properties fo:font-weight="bold"/>
</style:style>
<style:style style:name="T2" style:family="text">
  <style:text-properties fo:font-style="italic"/>
</style:style>
''',
      );

  /// Documento con lista puntata e ordinata.
  static Uint8List documentWithLists() => _buildOdt(
        contentBody: '''
<text:p text:style-name="P1">Lista non ordinata:</text:p>
<text:list text:style-name="L_bullet">
  <text:list-item><text:p>Mela</text:p></text:list-item>
  <text:list-item><text:p>Pera</text:p></text:list-item>
</text:list>
<text:p text:style-name="P1">Lista ordinata:</text:p>
<text:list text:style-name="L_ordered">
  <text:list-item><text:p>Primo</text:p></text:list-item>
  <text:list-item><text:p>Secondo</text:p></text:list-item>
</text:list>
''',
        autoStyles: '''
<text:list-style style:name="L_bullet">
  <text:list-level-style-bullet text:level="1" text:bullet-char="•"/>
</text:list-style>
<text:list-style style:name="L_ordered">
  <text:list-level-style-number text:level="1" style:num-format="1"/>
</text:list-style>
''',
      );

  /// Documento con un'immagine PNG 1×1 incorporata in `Pictures/`.
  static Uint8List documentWithImage() {
    // PNG 1×1 trasparente (header + IHDR + IDAT + IEND)
    final png = Uint8List.fromList(<int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);
    return _buildOdt(
      contentBody: '''
<text:p text:style-name="P1">Prima dell'immagine.</text:p>
<text:p text:style-name="P1"><draw:frame draw:name="Image1" svg:width="1cm" svg:height="1cm"><draw:image xlink:href="Pictures/img.png" xlink:type="simple"/></draw:frame></text:p>
<text:p text:style-name="P1">Dopo l'immagine.</text:p>
''',
      autoStyles: '',
      extraFiles: {'Pictures/img.png': png},
      manifestExtras:
          '<manifest:file-entry manifest:full-path="Pictures/img.png" manifest:media-type="image/png"/>',
    );
  }

  // ---------------------------------------------------------------------------
  // Builder ZIP
  // ---------------------------------------------------------------------------

  static Uint8List _buildOdt({
    required String contentBody,
    required String autoStyles,
    Map<String, Uint8List> extraFiles = const {},
    String manifestExtras = '',
  }) {
    final contentXml = _wrapContent(autoStyles, contentBody);
    final stylesXml = _stylesXml();
    final manifestXml = _manifestXml(extraFiles.keys, manifestExtras);

    final archive = Archive();

    // mimetype: deve essere il PRIMO file e STORED (compressionType=0).
    // Senza questo, alcuni reader rifiutano il file. Replica esattamente
    // ciò che fa LibreOffice.
    final mimetypeBytes = utf8.encode('application/vnd.oasis.opendocument.text');
    archive.addFile(
      ArchiveFile('mimetype', mimetypeBytes.length, mimetypeBytes)
        ..compression = CompressionType.none,
    );

    void addText(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addText('META-INF/manifest.xml', manifestXml);
    addText('content.xml', contentXml);
    addText('styles.xml', stylesXml);

    extraFiles.forEach((name, data) {
      archive.addFile(ArchiveFile(name, data.length, data));
    });

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _wrapContent(String autoStyles, String body) => '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
  xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
  xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
  xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
  xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
  office:version="1.3">
  <office:automatic-styles>
$autoStyles  </office:automatic-styles>
  <office:body>
    <office:text>
$body    </office:text>
  </office:body>
</office:document-content>
''';

  static String _stylesXml() => '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
  office:version="1.3">
  <office:styles/>
</office:document-styles>
''';

  static String _manifestXml(Iterable<String> extraPaths, String extras) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
  <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
  $extras
</manifest:manifest>
''';
  }
}
