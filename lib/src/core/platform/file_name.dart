/// Maximum length of a file name accepted by the file service.
const int maxFileNameLength = 100;

final RegExp _unsafeFileNameChars = RegExp(r'[^A-Za-z0-9._-]');

/// Keeps only `[A-Za-z0-9._-]`, replaces everything else with `_` and caps the
/// length at [maxFileNameLength]. Never returns an empty or dot-only name.
String sanitizeFileName(String name) {
  var clean = name.replaceAll(_unsafeFileNameChars, '_');
  if (clean.length > maxFileNameLength) {
    clean = clean.substring(0, maxFileNameLength);
  }
  if (clean.replaceAll('.', '').isEmpty) return 'file';
  return clean;
}
