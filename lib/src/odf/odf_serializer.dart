import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:folio/src/odf/style_collector.dart';

/// Serializza un [Delta] di flutter_quill in un file ODF (.odt) valido.
class OdfSerializer {
  static const _nsOffice = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  static const _nsText = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  static const _nsStyle = 'urn:oasis:names:tc:opendocument:xmlns:style:1.0';
  static const _nsFo =
      'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0';

  /// Converte un [Delta] flutter_quill in bytes di un file .odt valido.
  static Uint8List serialize(Delta delta) {
    final styleCollector = StyleCollector();
    final paragraphsXml = _buildParagraphsXml(delta, styleCollector);
    final autoStylesXml = styleCollector.buildAutoStylesXml();

    final contentXml = _buildContentXml(autoStylesXml, paragraphsXml);
    return _buildZip(contentXml);
  }

  static String _buildContentXml(String autoStylesXml, String paragraphsXml) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
              <office:document-content
                xmlns:office="$_nsOffice"
                xmlns:text="$_nsText"
                xmlns:style="$_nsStyle"
                xmlns:fo="$_nsFo"
                office:version="1.3">
                <office:automatic-styles>
                  $autoStylesXml$_listStylesXml
                </office:automatic-styles>
                <office:body>
                  <office:text>
                    $paragraphsXml
                  </office:text>
                </office:body>
              </office:document-content>''';
  }

  /// Dichiarazioni delle liste (`L_bullet`, `L_ordered`) replicate in
  /// `content.xml`. Necessarie per il round-trip: il parser legge solo
  /// `content.xml`, quindi senza queste dichiarazioni un'eventuale lista
  /// ordinata risulterebbe demoted a bullet alla riapertura.
  static const String _listStylesXml =
      '''    <text:list-style style:name="L_bullet">
      <text:list-level-style-bullet text:level="1" text:bullet-char="&#x2022;"/>
    </text:list-style>
    <text:list-style style:name="L_ordered">
      <text:list-level-style-number text:level="1" style:num-format="1"/>
    </text:list-style>
''';

  /// Itera le operazioni del [Delta] e produce le righe XML dei paragrafi.
  static String _buildParagraphsXml(Delta delta, StyleCollector collector) {
    final ops = delta.toList();
    final buffer = StringBuffer();

    final blocks = _splitIntoBlocks(ops);

    for (final block in blocks) {
      _writeBlock(block, collector, buffer);
    }

    return buffer.toString();
  }

  /// Divide la lista piatta di [Operation] in blocchi logici.
  static List<List<Operation>> _splitIntoBlocks(List<Operation> ops) {
    final blocks = <List<Operation>>[];
    var current = <Operation>[];

    for (final op in ops) {
      if (op.data is! String) continue;
      final text = op.data as String;

      var start = 0;
      for (var i = 0; i < text.length; i++) {
        if (text[i] == '\n') {
          if (i > start) {
            current.add(
              Operation.insert(text.substring(start, i), op.attributes),
            );
          }
          current.add(Operation.insert('\n', op.attributes));
          blocks.add(List.unmodifiable(current));
          current = [];
          start = i + 1;
        }
      }

      if (start < text.length) {
        current.add(Operation.insert(text.substring(start), op.attributes));
      }
    }

    if (current.isNotEmpty) {
      blocks.add(List.unmodifiable(current));
    }

    return blocks;
  }

  /// Scrive un singolo blocco come elemento XML (paragrafo, heading, lista…).
  static void _writeBlock(
    List<Operation> block,
    StyleCollector collector,
    StringBuffer out,
  ) {
    if (block.isEmpty) return;

    final newlineOp = block.lastWhere(
      (op) => op.data == '\n',
      orElse: () => Operation.insert('\n'),
    );
    final paraAttrs = newlineOp.attributes ?? {};

    final contentOps = block.where((op) => op.data != '\n').toList();

    final listType = paraAttrs['list'] as String?;
    final headerLevel = paraAttrs['header'];

    if (listType != null) {
      _writeListItem(contentOps, listType, collector, out);
    } else if (headerLevel != null) {
      _writeHeading(contentOps, headerLevel as int, collector, out);
    } else {
      _writeParagraph(contentOps, collector, out);
    }
  }

  static void _writeParagraph(
    List<Operation> ops,
    StyleCollector collector,
    StringBuffer out,
  ) {
    out.write('      <text:p text:style-name="Standard">');
    _writeInlineOps(ops, collector, out);
    out.writeln('</text:p>');
  }

  static void _writeHeading(
    List<Operation> ops,
    int level,
    StyleCollector collector,
    StringBuffer out,
  ) {
    final safeLevel = level.clamp(1, 6);
    out.write(
      '      <text:h text:outline-level="$safeLevel"'
      ' text:style-name="Heading_20_$safeLevel">',
    );
    _writeInlineOps(ops, collector, out);
    out.writeln('</text:h>');
  }

  static void _writeListItem(
    List<Operation> ops,
    String listType,
    StyleCollector collector,
    StringBuffer out,
  ) {
    final styleName = listType == 'ordered' ? 'L_ordered' : 'L_bullet';
    out.writeln('      <text:list text:style-name="$styleName">');
    out.write('        <text:list-item><text:p>');
    _writeInlineOps(ops, collector, out);
    out.writeln('</text:p></text:list-item>');
    out.writeln('      </text:list>');
  }

  static void _writeInlineOps(
    List<Operation> ops,
    StyleCollector collector,
    StringBuffer out,
  ) {
    for (final op in ops) {
      if (op.data is! String) continue;
      final text = op.data as String;
      if (text.isEmpty) continue;

      final attrs = op.attributes;
      if (attrs == null || attrs.isEmpty) {
        out.write(_escapeXml(text));
      } else {
        final styleName = collector.styleNameFor(attrs);
        out.write('<text:span text:style-name="$styleName">');
        out.write(_escapeXml(text));
        out.write('</text:span>');
      }
    }
  }

  static Uint8List _buildZip(String contentXml) {
    final archive = Archive();

    final mimetypeBytes = utf8.encode(
      'application/vnd.oasis.opendocument.text',
    );
    archive.addFile(
      ArchiveFile.noCompress('mimetype', mimetypeBytes.length, mimetypeBytes),
    );

    final manifestXml = _buildManifestXml();
    final manifestBytes = utf8.encode(manifestXml);
    archive.addFile(
      ArchiveFile('META-INF/manifest.xml', manifestBytes.length, manifestBytes),
    );

    final contentBytes = utf8.encode(contentXml);
    archive.addFile(
      ArchiveFile('content.xml', contentBytes.length, contentBytes),
    );

    final stylesXml = _buildStylesXml();
    final stylesBytes = utf8.encode(stylesXml);
    archive.addFile(ArchiveFile('styles.xml', stylesBytes.length, stylesBytes));

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _buildManifestXml() => '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest
  xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"
  manifest:version="1.3">
  <manifest:file-entry
    manifest:full-path="/"
    manifest:version="1.3"
    manifest:media-type="application/vnd.oasis.opendocument.text"/>
  <manifest:file-entry
    manifest:full-path="content.xml"
    manifest:media-type="text/xml"/>
  <manifest:file-entry
    manifest:full-path="styles.xml"
    manifest:media-type="text/xml"/>
</manifest:manifest>''';

  static String _buildStylesXml() =>
      '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles
  xmlns:office="$_nsOffice"
  xmlns:style="$_nsStyle"
  xmlns:fo="$_nsFo"
  xmlns:text="$_nsText"
  office:version="1.3">
  <office:styles>
    <style:style style:name="Standard" style:family="paragraph"
      style:class="text"/>
    <style:style style:name="Heading_20_1" style:display-name="Heading 1"
      style:family="paragraph" style:parent-style-name="Standard"
      style:class="text">
      <style:paragraph-properties fo:margin-top="0.423cm"
        fo:margin-bottom="0.212cm"/>
      <style:text-properties fo:font-size="24pt" fo:font-weight="bold"/>
    </style:style>
    <style:style style:name="Heading_20_2" style:display-name="Heading 2"
      style:family="paragraph" style:parent-style-name="Standard"
      style:class="text">
      <style:paragraph-properties fo:margin-top="0.353cm"
        fo:margin-bottom="0.212cm"/>
      <style:text-properties fo:font-size="18pt" fo:font-weight="bold"/>
    </style:style>
    <style:style style:name="Heading_20_3" style:display-name="Heading 3"
      style:family="paragraph" style:parent-style-name="Standard"
      style:class="text">
      <style:paragraph-properties fo:margin-top="0.247cm"
        fo:margin-bottom="0.212cm"/>
      <style:text-properties fo:font-size="14pt" fo:font-weight="bold"/>
    </style:style>
  </office:styles>
  <office:automatic-styles>
    <text:list-style style:name="L_bullet">
      <text:list-level-style-bullet text:level="1"
        text:bullet-char="&#x2022;">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab"
            fo:margin-left="0.635cm" fo:text-indent="-0.635cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
    </text:list-style>
    <text:list-style style:name="L_ordered">
      <text:list-level-style-number text:level="1"
        text:start-value="1" style:num-format="1"
        style:num-suffix=".">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab"
            fo:margin-left="0.635cm" fo:text-indent="-0.635cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
    </text:list-style>
  </office:automatic-styles>
</office:document-styles>''';

  /// Esegue l'escape dei caratteri speciali XML.
  static String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
