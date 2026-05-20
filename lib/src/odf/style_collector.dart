/// Accumula gli stili inline (bold, italic, ecc.) generati durante la
/// serializzazione e assegna loro nomi univoci.
class StyleCollector {
  final _styles = <Map<String, dynamic>, String>{};
  var _counter = 0;

  /// Restituisce il nome dello stile per un insieme di attributi Quill.
  String styleNameFor(Map<String, dynamic> attrs) {
    return _styles.putIfAbsent(Map.unmodifiable(attrs), () {
      _counter++;
      return 'T$_counter';
    });
  }

  /// Genera il blocco XML `<office:automatic-styles>` per tutti gli stili
  /// raccolti.
  String buildAutoStylesXml() {
    if (_styles.isEmpty) return '';

    final buf = StringBuffer();
    for (final entry in _styles.entries) {
      final attrs = entry.key;
      final name = entry.value;
      buf.writeln('    <style:style style:name="$name" style:family="text">');
      buf.write('      <style:text-properties');

      if (attrs['bold'] == true) {
        buf.write(' fo:font-weight="bold"');
      }
      if (attrs['italic'] == true) {
        buf.write(' fo:font-style="italic"');
      }
      if (attrs['underline'] == true) {
        buf.write(' style:text-underline-style="solid"');
        buf.write(' style:text-underline-width="auto"');
        buf.write(' style:text-underline-color="font-color"');
      }
      if (attrs['strike'] == true) {
        buf.write(' style:text-line-through-style="solid"');
      }
      if (attrs['color'] is String) {
        buf.write(' fo:color="${attrs['color']}"');
      }
      if (attrs['size'] is String) {
        buf.write(' fo:font-size="${attrs['size']}"');
      }

      buf.writeln('/>');
      buf.writeln('    </style:style>');
    }
    return buf.toString();
  }
}
