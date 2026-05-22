import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;

import 'conversion_exception.dart';
import 'converter.dart';

/// Converter bidirezionale per file Markdown (`.md`).
class MdConverter extends DocumentConverter {
  const MdConverter();

  @override
  String get extension => 'md';

  @override
  Delta fromBytes(Uint8List bytes) {
    final String source;
    try {
      source = utf8.decode(bytes);
    } catch (e) {
      throw ConversionException(ConversionErrorKind.notValidUtf8, e);
    }
    try {
      return _mdToDelta(source);
    } catch (e) {
      throw ConversionException(ConversionErrorKind.markdownConversionFailed, e);
    }
  }

  Delta _mdToDelta(String source) {
    final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = document.parseLines(source.split('\n'));
    final builder = _DeltaBuilder();
    for (final node in nodes) {
      node.accept(builder);
    }
    builder.flush();
    if (builder.delta.isEmpty) return Delta()..insert('\n');
    return builder.delta;
  }

  @override
  Uint8List toBytes(Delta delta) {
    final md = _deltaToMd(delta);
    return utf8.encode(md);
  }

  String _deltaToMd(Delta delta) {
    final buf = StringBuffer();
    final List<({String text, Map<String, dynamic>? attrs})> line = [];

    void flushLine() {
      if (line.isEmpty) return;

      final blockAttrs = line.last.attrs;
      final header = blockAttrs?['header'];
      final listAttr = blockAttrs?['list'];
      final isBlockquote = blockAttrs?['blockquote'] == true;
      final isCode = blockAttrs?['code-block'] == true;

      final inlineBuf = StringBuffer();
      for (var i = 0; i < line.length - 1; i++) {
        final op = line[i];
        var t = op.text;
        final a = op.attrs ?? {};
        if (a['code'] == true) {
          t = '`$t`';
        } else {
          if (a['bold'] == true) t = '**$t**';
          if (a['italic'] == true) t = '_${t}_';
          if (a['underline'] == true) t = '<u>$t</u>';
          if (a['strike'] == true) t = '~~$t~~';
        }
        inlineBuf.write(t);
      }
      final inlineText = inlineBuf.toString();

      if (isCode) {
        buf.writeln('```');
        buf.writeln(inlineText);
        buf.writeln('```');
      } else if (isBlockquote) {
        buf.writeln('> $inlineText');
      } else if (header is int && header >= 1 && header <= 6) {
        buf.writeln('${'#' * header} $inlineText');
      } else if (listAttr == 'ordered') {
        buf.writeln('1. $inlineText');
      } else if (listAttr == 'bullet') {
        buf.writeln('- $inlineText');
      } else {
        buf.writeln(inlineText);
      }

      line.clear();
    }

    for (final op in delta.toList()) {
      final data = op.data;
      if (data is! String) continue;
      final attrs = op.attributes?.cast<String, dynamic>();

      final parts = data.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          line.add((text: parts[i], attrs: attrs));
        }
        if (i < parts.length - 1) {
          line.add((text: '\n', attrs: attrs));
          flushLine();
        }
      }
    }
    if (line.isNotEmpty) {
      line.add((text: '\n', attrs: null));
      flushLine();
    }

    return buf.toString();
  }
}

class _DeltaBuilder implements md.NodeVisitor {
  final Delta delta = Delta();

  final List<Map<String, dynamic>> _attrStack = [];
  Map<String, dynamic> _blockAttrs = {};
  final StringBuffer _buf = StringBuffer();
  String? _listType;
  int _codeBlockDepth = 0;

  Map<String, dynamic> get _currentAttrs {
    final merged = <String, dynamic>{};
    for (final m in _attrStack) {
      merged.addAll(m);
    }
    return merged;
  }

  void _flushText({Map<String, dynamic>? extra}) {
    final text = _buf.toString();
    _buf.clear();
    if (text.isEmpty) return;
    final attrs = {..._currentAttrs, ...?extra};
    if (attrs.isEmpty) {
      delta.insert(text);
    } else {
      delta.insert(text, attrs);
    }
  }

  void _closeBlock() {
    _flushText();
    if (_blockAttrs.isEmpty) {
      delta.insert('\n');
    } else {
      delta.insert('\n', Map.of(_blockAttrs));
    }
    _blockAttrs = {};
  }

  void flush() {
    if (_buf.isNotEmpty) _closeBlock();
  }

  @override
  bool visitElementBefore(md.Element element) {
    switch (element.tag) {
      case 'h1':
        _blockAttrs['header'] = 1;
      case 'h2':
        _blockAttrs['header'] = 2;
      case 'h3':
        _blockAttrs['header'] = 3;
      case 'h4':
        _blockAttrs['header'] = 4;
      case 'h5':
        _blockAttrs['header'] = 5;
      case 'h6':
        _blockAttrs['header'] = 6;
      case 'strong':
        _flushText();
        _attrStack.add({'bold': true});
      case 'em':
        _flushText();
        _attrStack.add({'italic': true});
      case 'del':
        _flushText();
        _attrStack.add({'strike': true});
      case 'code':
        if (_codeBlockDepth == 0) {
          _flushText();
          _attrStack.add({'code': true});
        }
      case 'pre':
        _codeBlockDepth++;
        _blockAttrs['code-block'] = true;
      case 'blockquote':
        _blockAttrs['blockquote'] = true;
      case 'ul':
        _listType = 'bullet';
      case 'ol':
        _listType = 'ordered';
      case 'li':
        if (_listType != null) _blockAttrs['list'] = _listType;
      case 'a':
        _flushText();
        final href = element.attributes['href'];
        if (href != null) _attrStack.add({'link': href});
      case 'p':
      case 'br':
        break;
    }
    return true;
  }

  @override
  void visitElementAfter(md.Element element) {
    switch (element.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'p':
      case 'li':
      case 'blockquote':
        _closeBlock();
      case 'pre':
        _codeBlockDepth--;
        _closeBlock();
      case 'strong':
      case 'em':
      case 'del':
      case 'code':
      case 'a':
        _flushText();
        if (_attrStack.isNotEmpty) _attrStack.removeLast();
      case 'ul':
      case 'ol':
        _listType = null;
    }
  }

  @override
  void visitText(md.Text text) {
    _buf.write(text.textContent);
  }
}
