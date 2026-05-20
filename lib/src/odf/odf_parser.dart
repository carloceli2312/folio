
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:xml/xml.dart';

import 'odf_exceptions.dart';

/// Parses ODF (.odt) files and converts their content to a flutter_quill
/// [Delta] document.
class OdfParser {
  static const _officeNs = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  static const _textNs = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  static const _styleNs = 'urn:oasis:names:tc:opendocument:xmlns:style:1.0';
  static const _foNs =
      'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0';
  static const _drawNs = 'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0';
  static const _xlinkNs = 'http://www.w3.org/1999/xlink';
  static const _tableNs = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0';

  /// Opens an ODF file from its raw [bytes], extracts [content.xml] and
  /// returns the document as a flutter_quill [Delta].
  static Delta parse(Uint8List bytes) {

    if (bytes.length < 22) {
      throw const OdfInvalidArchiveException();
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on ArchiveException catch (e) {
      throw OdfInvalidArchiveException(e);
    } catch (e) {
      throw OdfInvalidArchiveException(e);
    }

    final entry = archive.findFile('content.xml');
    if (entry == null) {
      throw const OdfMissingContentException();
    }

    final String xmlContent;
    try {
      xmlContent = utf8.decode(entry.content as List<int>);
    } on FormatException catch (e) {
      throw OdfMalformedXmlException(e);
    }

    try {
      return _parseWithArchive(xmlContent, archive);
    } on OdfException {
      rethrow;
    } on XmlException catch (e) {
      throw OdfMalformedXmlException(e);
    } catch (e) {
      throw OdfUnknownException(e);
    }
  }

  /// Parses an ODF [content.xml] string and returns a [Delta].
  static Delta parseContentXml(String xmlContent) {
    try {
      return _parseWithArchive(xmlContent, null);
    } on XmlException catch (e) {
      throw OdfMalformedXmlException(e);
    }
  }

  static Delta _parseWithArchive(String xmlContent, Archive? archive) {
    final doc = XmlDocument.parse(xmlContent);
    final styles = _parseStyles(doc);
    return _buildDelta(doc, styles, archive);
  }

  /// Builds a map of style-name → Quill text-attribute map from the
  /// [<office:automatic-styles>] section of [doc].
  static Map<String, Map<String, dynamic>> _parseStyles(XmlDocument doc) {
    final result = <String, Map<String, dynamic>>{};

    for (final styleEl in doc.findAllElements('style', namespace: _styleNs)) {
      final name = styleEl.getAttribute('name', namespace: _styleNs);
      if (name == null) continue;

      final attrs = <String, dynamic>{};

      final textProps = styleEl
          .findElements('text-properties', namespace: _styleNs)
          .firstOrNull;

      if (textProps != null) {
        if (textProps.getAttribute('font-weight', namespace: _foNs) == 'bold') {
          attrs['bold'] = true;
        }
        if (textProps.getAttribute('font-style', namespace: _foNs) ==
            'italic') {
          attrs['italic'] = true;
        }
        final underline = textProps.getAttribute(
          'text-underline-style',
          namespace: _styleNs,
        );
        if (underline != null && underline != 'none') {
          attrs['underline'] = true;
        }
        final strikeThrough = textProps.getAttribute(
          'text-line-through-style',
          namespace: _styleNs,
        );
        if (strikeThrough != null && strikeThrough != 'none') {
          attrs['strike'] = true;
        }
        final color = textProps.getAttribute('color', namespace: _foNs);
        if (color != null) attrs['color'] = color;

        final fontSize = textProps.getAttribute('font-size', namespace: _foNs);
        if (fontSize != null) attrs['size'] = fontSize;
      }

      result[name] = attrs;
    }

    return result;
  }

  static Delta _buildDelta(
    XmlDocument doc,
    Map<String, Map<String, dynamic>> styles,
    Archive? archive,
  ) {
    final delta = Delta();

    final bodyEl = doc
        .findAllElements('body', namespace: _officeNs)
        .firstOrNull;
    if (bodyEl == null) return delta..insert('\n');

    final textEl = bodyEl
        .findElements('text', namespace: _officeNs)
        .firstOrNull;
    if (textEl == null) return delta..insert('\n');

    final listStyles = _parseListStyles(doc);

    var hasContent = false;
    for (final child in textEl.childElements) {
      switch (child.namespaceUri) {
        case _textNs:
          switch (child.localName) {
            case 'p':
              _parseParagraph(child, styles, delta, archive, isHeading: false);
              hasContent = true;
            case 'h':
              _parseParagraph(child, styles, delta, archive, isHeading: true);
              hasContent = true;
            case 'list':
              _parseList(child, styles, listStyles, delta, archive);
              hasContent = true;
          }
        case _tableNs:
          if (child.localName == 'table') {
            _parseTable(child, styles, delta, archive);
            hasContent = true;
          }
      }
    }

    if (!hasContent) {
      delta.insert('\n');
    }

    return delta;
  }

  /// Converts a [<text:p>] or [<text:h>] element into Delta operations,
  /// terminated by a newline (with optional heading attribute).
  static void _parseParagraph(
    XmlElement element,
    Map<String, Map<String, dynamic>> styles,
    Delta delta,
    Archive? archive, {
    required bool isHeading,
  }) {
    _parseInlineContent(element, styles, {}, delta, archive);

    final paraAttrs = <String, dynamic>{};
    if (isHeading) {
      final level = element.getAttribute('outline-level', namespace: _textNs);
      paraAttrs['header'] = int.tryParse(level ?? '') ?? 1;
    }

    delta.insert('\n', paraAttrs.isEmpty ? null : paraAttrs);
  }

  /// Recursively walks the children of [element], accumulating text runs into
  /// [delta]. [inheritedAttrs] carry formatting from enclosing spans.
  static void _parseInlineContent(
    XmlElement element,
    Map<String, Map<String, dynamic>> styles,
    Map<String, dynamic> inheritedAttrs,
    Delta delta,
    Archive? archive,
  ) {
    for (final node in element.children) {
      if (node is XmlText) {
        final text = node.value;
        if (text.isNotEmpty) {
          delta.insert(text, inheritedAttrs.isEmpty ? null : inheritedAttrs);
        }
      } else if (node is XmlElement) {
        switch (node.namespaceUri) {
          case _textNs:
            _handleTextElement(node, styles, inheritedAttrs, delta, archive);
          case _drawNs:
            if (node.localName == 'frame') {
              _parseDrawFrame(node, delta, archive);
            }
        }
      }
    }
  }

  /// Gestisce gli elementi nel namespace `text:`.
  static void _handleTextElement(
    XmlElement node,
    Map<String, Map<String, dynamic>> styles,
    Map<String, dynamic> inheritedAttrs,
    Delta delta,
    Archive? archive,
  ) {
    switch (node.localName) {
      case 'span':
        final spanStyleName = node.getAttribute(
          'style-name',
          namespace: _textNs,
        );
        final spanAttrs = <String, dynamic>{...inheritedAttrs};
        if (spanStyleName != null) {
          spanAttrs.addAll(styles[spanStyleName] ?? {});
        }
        _parseInlineContent(node, styles, spanAttrs, delta, archive);
      case 'a':
        final url = node.getAttribute('href', namespace: _xlinkNs);
        final linkAttrs = <String, dynamic>{...inheritedAttrs};
        if (url != null && url.isNotEmpty) {
          linkAttrs['link'] = url;
        }
        _parseInlineContent(node, styles, linkAttrs, delta, archive);
      case 'line-break':
        delta.insert('\n', inheritedAttrs.isEmpty ? null : inheritedAttrs);
      case 's':
        final count =
            int.tryParse(node.getAttribute('c', namespace: _textNs) ?? '1') ??
            1;
        delta.insert(
          ' ' * count,
          inheritedAttrs.isEmpty ? null : inheritedAttrs,
        );
      case 'tab':
        delta.insert('\t', inheritedAttrs.isEmpty ? null : inheritedAttrs);
    }
  }

  /// Parsa un elemento `<draw:frame>` che può contenere un'immagine.
  static void _parseDrawFrame(
    XmlElement frameEl,
    Delta delta,
    Archive? archive,
  ) {
    final imageEl = frameEl
        .findElements('image', namespace: _drawNs)
        .firstOrNull;
    if (imageEl == null) return;

    final href = imageEl.getAttribute('href', namespace: _xlinkNs);
    if (href == null || href.isEmpty) {
      delta.insert('[immagine]');
      return;
    }

    if (archive == null) {
      delta.insert('[immagine]');
      return;
    }

    final imageEntry = archive.findFile(href);
    if (imageEntry == null) {
      delta.insert('[immagine]');
      return;
    }

    final imageBytes = imageEntry.content as List<int>;
    final base64Data = base64Encode(imageBytes);
    final mimeType = _guessMimeType(href);
    final dataUri = 'data:$mimeType;base64,$base64Data';

    delta.insert({'image': dataUri});
    delta.insert('\n');
  }

  /// Inferisce il MIME type dell'immagine dall'estensione del file.
  static String _guessMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
  }

  /// Parsa un elemento `<table:table>` e lo converte in testo strutturato.
  static void _parseTable(
    XmlElement tableEl,
    Map<String, Map<String, dynamic>> styles,
    Delta delta,
    Archive? archive,
  ) {
    final rows = tableEl
        .findElements('table-row', namespace: _tableNs)
        .toList();
    if (rows.isEmpty) return;

    var isFirstRow = true;
    for (final row in rows) {
      final cells = row
          .findElements('table-cell', namespace: _tableNs)
          .toList();
      final cellTexts = <String>[];

      for (final cell in cells) {
        final cellDelta = Delta();
        for (final child in cell.childElements) {
          if (child.namespaceUri == _textNs &&
              (child.localName == 'p' || child.localName == 'h')) {
            _parseInlineContent(child, styles, {}, cellDelta, archive);
          }
        }
        final text = cellDelta
            .toList()
            .map((op) => op.data is String ? op.data as String : '')
            .join()
            .trim();
        cellTexts.add(text);
      }

      if (cellTexts.isEmpty) continue;

      delta.insert(cellTexts.join(' | '));
      delta.insert('\n');

      if (isFirstRow) {
        final separator = cellTexts
            .map((c) => '-' * c.length.clamp(3, 20))
            .join('-+-');
        delta.insert(separator);
        delta.insert('\n');
        isFirstRow = false;
      }
    }
  }

  /// Builds a map of list-style-name → `'ordered'` or `'bullet'` by inspecting
  /// [<text:list-style>] elements in the document's automatic-styles section.
  static Map<String, String> _parseListStyles(XmlDocument doc) {
    final result = <String, String>{};

    for (final listStyle in doc.findAllElements(
      'list-style',
      namespace: _textNs,
    )) {
      final name = listStyle.getAttribute('name', namespace: _styleNs);
      if (name == null) continue;

      final isOrdered = listStyle
          .findElements('list-level-style-number', namespace: _textNs)
          .isNotEmpty;
      result[name] = isOrdered ? 'ordered' : 'bullet';
    }

    return result;
  }

  /// Converts a [<text:list>] element into Delta list operations.
  static void _parseList(
    XmlElement listEl,
    Map<String, Map<String, dynamic>> styles,
    Map<String, String> listStyles,
    Delta delta,
    Archive? archive,
  ) {
    final styleName = listEl.getAttribute('style-name', namespace: _textNs);
    final listType =
        (styleName != null ? listStyles[styleName] : null) ?? 'bullet';

    for (final item in listEl.findElements('list-item', namespace: _textNs)) {
      for (final child in item.childElements) {
        if (child.namespaceUri == _textNs &&
            (child.localName == 'p' || child.localName == 'h')) {
          _parseInlineContent(child, styles, {}, delta, archive);
          delta.insert('\n', {'list': listType});
        }
      }
    }
  }
}
