import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../core/utils/js_number.dart';
import '../domain/entities/geometry.dart';
import '../domain/services/survey_row_parser.dart';

/// Files larger than this are rejected before decoding.
const int maxSpreadsheetBytes = 20 * 1024 * 1024;

/// Rows beyond this count per sheet are ignored.
const int maxRowsPerSheet = 200000;

/// Text cells are clamped to this length (names are cut to 64 anyway).
const int maxCellTextLength = 256;

/// Thrown for unreadable or oversized spreadsheets.
final class SpreadsheetException implements Exception {
  const SpreadsheetException(this.message);

  final String message;

  @override
  String toString() => 'SpreadsheetException: $message';
}

/// Reads and writes `.xlsx` workbooks (package:excel) in the shapes the
/// domain expects.
final class XlsxSpreadsheetCodec {
  const XlsxSpreadsheetCodec();

  static const String breaklinesSheetName = 'Breaklines';
  static const String breaklinesMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Decodes [bytes] into sheets of rows keyed by the first-row headers, like
  /// SheetJS `sheet_to_json`: empty cells omitted, duplicate headers get a
  /// `_1`, `_2`... suffix, fully empty rows skipped.
  List<List<SurveyRow>> decode(Uint8List bytes) {
    if (bytes.length > maxSpreadsheetBytes) {
      throw const SpreadsheetException('File too large');
    }
    final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } on Object catch (e) {
      throw SpreadsheetException('Cannot read workbook: $e');
    }
    return [for (final sheet in workbook.tables.values) _sheetRows(sheet)];
  }

  List<SurveyRow> _sheetRows(Sheet sheet) {
    final grid = sheet.rows;
    if (grid.isEmpty) return const [];
    final headers = _headers(grid.first);
    final rows = <SurveyRow>[];
    for (final cells in grid.skip(1).take(maxRowsPerSheet)) {
      final row = <String, Object?>{};
      headers.forEach((col, header) {
        final value = col < cells.length ? _cellValue(cells[col]?.value) : null;
        if (value != null) row[header] = value;
      });
      if (row.isNotEmpty) rows.add(row);
    }
    return rows;
  }

  Map<int, String> _headers(List<Data?> cells) {
    final headers = <int, String>{};
    final seen = <String, int>{};
    for (var col = 0; col < cells.length; col++) {
      final raw = _cellValue(cells[col]?.value);
      if (raw == null) continue;
      final base = raw is double && raw == raw.truncateToDouble()
          ? raw.toInt().toString()
          : raw.toString();
      final count = seen[base] ?? 0;
      seen[base] = count + 1;
      headers[col] = count == 0 ? base : '${base}_$count';
    }
    return headers;
  }

  Object? _cellValue(CellValue? value) => switch (value) {
    null => null,
    IntCellValue(:final value) => value,
    DoubleCellValue(:final value) => value,
    BoolCellValue(:final value) => value,
    TextCellValue() => _nonEmpty(_clamp(value.toString())),
    FormulaCellValue() => null,
    _ => _clamp(value.toString()),
  };

  String _clamp(String text) => text.length > maxCellTextLength
      ? text.substring(0, maxCellTextLength)
      : text;

  String? _nonEmpty(String text) => text.isEmpty ? null : text;

  /// Builds the breaklines export: one sheet `Breaklines` with columns
  /// Breakline, Index (1-based), X, Y, Z (coordinates as 3-decimal text).
  Uint8List encodeBreaklines(List<BreakLine> breakLines) {
    final workbook = Excel.createExcel();
    final defaultName =
        workbook.getDefaultSheet() ?? workbook.tables.keys.first;
    workbook.rename(defaultName, breaklinesSheetName);
    final sheet = workbook[breaklinesSheetName]
      ..appendRow([
        TextCellValue('Breakline'),
        TextCellValue('Index'),
        TextCellValue('X'),
        TextCellValue('Y'),
        TextCellValue('Z'),
      ]);
    for (final bl in breakLines) {
      for (var i = 0; i < bl.points.length; i++) {
        final p = bl.points[i];
        sheet.appendRow([
          TextCellValue(bl.name),
          IntCellValue(i + 1),
          TextCellValue(p.x.toFixed(3)),
          TextCellValue(p.y.toFixed(3)),
          TextCellValue(p.z.toFixed(3)),
        ]);
      }
    }
    final encoded = workbook.encode();
    if (encoded == null) {
      throw const SpreadsheetException('Cannot encode workbook');
    }
    return Uint8List.fromList(encoded);
  }
}
