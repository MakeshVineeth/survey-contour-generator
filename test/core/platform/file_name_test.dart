import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/core/platform/file_name.dart';

void main() {
  test('keeps allowed characters', () {
    expect(
      sanitizeFileName('contour-2026-01-02-R12.dxf'),
      'contour-2026-01-02-R12.dxf',
    );
  });

  test('replaces unsafe characters', () {
    expect(sanitizeFileName('a b/c\\d:e*.txt'), 'a_b_c_d_e_.txt');
    expect(sanitizeFileName('café.txt'), 'caf_.txt');
  });

  test('caps length at 100', () {
    expect(sanitizeFileName('a' * 300).length, maxFileNameLength);
  });

  test('never empty or dot-only', () {
    expect(sanitizeFileName(''), 'file');
    expect(sanitizeFileName('..'), 'file');
  });
}
