/// Sanitizes user-supplied labels before they are embedded in CAD files.
///
/// Survey data comes from arbitrary spreadsheets. A label containing a quote,
/// backslash or line break would corrupt a DXF group code or terminate an
/// AutoLISP string literal early (code injection when the `.lsp` is loaded).
/// Ordinary names pass through unchanged.
String sanitizeCadText(String input) {
  final buffer = StringBuffer();
  for (final unit in input.runes) {
    if (unit < 0x20 || unit == 0x7f) continue;
    if (unit == 0x22) {
      buffer.write("'");
    } else if (unit == 0x5c) {
      buffer.write('/');
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}
