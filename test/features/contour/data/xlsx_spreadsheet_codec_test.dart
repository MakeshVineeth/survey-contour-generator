import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/data/xlsx_spreadsheet_codec.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/survey_row_parser.dart';

Uint8List _book(List<List<CellValue?>> rows) {
  final wb = Excel.createExcel();
  final sheet = wb[wb.getDefaultSheet()!];
  rows.forEach(sheet.appendRow);
  return Uint8List.fromList(wb.encode()!);
}

TextCellValue _t(String s) => TextCellValue(s);

void main() {
  const codec = XlsxSpreadsheetCodec();

  test('breaklines round trip', () {
    final bytes = codec.encodeBreaklines(const [
      BreakLine(name: 'BL-1', points: [Point3(1, 2, 3), Point3(4.5, 5.25, 6)]),
      BreakLine(name: 'BL-2', points: [Point3(-1, 0, 0.0004)]),
    ]);
    final rows = codec.decode(bytes).single;
    expect(rows.length, 3);
    expect(rows[0], {
      'Breakline': 'BL-1',
      'Index': 1,
      'X': '1.000',
      'Y': '2.000',
      'Z': '3.000',
    });
    expect(rows[1]['X'], '4.500');
    expect(rows[1]['Y'], '5.250');
    expect(rows[2]['Breakline'], 'BL-2');
    expect(rows[2]['Z'], '0.000');
  });

  test('sheet is named Breaklines', () {
    final bytes = codec.encodeBreaklines(const [
      BreakLine(name: 'A', points: [Point3(0, 0, 0)]),
    ]);
    expect(Excel.decodeBytes(bytes).tables.keys, ['Breaklines']);
  });

  test('decodes headers, omits empty cells, keeps numbers as num', () {
    final bytes = _book([
      [_t('BH'), _t('X'), _t('Y'), _t('RL')],
      [_t('P1'), const DoubleCellValue(1.5), const IntCellValue(2), null],
      [null, null, null, null],
      [_t('P2'), _t('10m'), const IntCellValue(0), const IntCellValue(7)],
    ]);
    final rows = codec.decode(bytes).single;
    expect(rows.length, 2);
    expect(rows[0], {'BH': 'P1', 'X': 1.5, 'Y': 2});
    expect(rows[1], {'BH': 'P2', 'X': '10m', 'Y': 0, 'RL': 7});
  });

  test('decoded workbook feeds the parser', () {
    final bytes = _book([
      [_t('ID'), _t('E'), _t('N'), _t('Z')],
      [
        _t('A'),
        const IntCellValue(0),
        const IntCellValue(0),
        const IntCellValue(0),
      ],
    ]);
    final res = SurveyRowParser.parse(codec.decode(bytes));
    expect(res.points.single.borehole, 'A');
  });

  test('rejects oversized and corrupt input', () {
    expect(
      () => codec.decode(Uint8List(maxSpreadsheetBytes + 1)),
      throwsA(isA<SpreadsheetException>()),
    );
    expect(
      () => codec.decode(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<SpreadsheetException>()),
    );
  });
}
