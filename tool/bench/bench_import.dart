// ignore_for_file: avoid_print, prefer_final_locals
// Run: dart run tool/bench/bench_import.dart [sizes...]
// Generates an N-row workbook, then measures codec decode + SurveyRowParser,
// plus the cost of copying the result across an isolate boundary.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:survey_contour_generator/src/features/contour/data/xlsx_spreadsheet_codec.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/survey_import.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/survey_row_parser.dart';

import 'bench_data.dart';

int rss() => ProcessInfo.currentRss;

Uint8List buildWorkbook(int n) {
  final book = Excel.createExcel();
  final name = book.getDefaultSheet()!;
  final sheet = book[name];
  sheet.appendRow([
    TextCellValue('BoreholeID'),
    TextCellValue('X'),
    TextCellValue('Y'),
    TextCellValue('RL'),
  ]);
  for (final p in generateSurvey(n)) {
    sheet.appendRow([
      TextCellValue(p.borehole),
      DoubleCellValue(p.x),
      DoubleCellValue(p.y),
      DoubleCellValue(p.z),
    ]);
  }
  return Uint8List.fromList(book.encode()!);
}

SurveyImportResult parseWorkbook(Uint8List bytes) =>
    SurveyRowParser.parse(const XlsxSpreadsheetCodec().decode(bytes));

Future<void> main(List<String> args) async {
  final sizes = args.isEmpty ? [100, 1000, 5000, 20000] : args.map(int.parse).toList();
  for (final n in sizes) {
    stdout.writeln('== rows=$n');
    final bytes = buildWorkbook(n);
    stdout.writeln('  xlsx bytes ${(bytes.length / 1024).toStringAsFixed(0)} KB');
    var before = rss();
    var sw = Stopwatch()..start();
    final rows = const XlsxSpreadsheetCodec().decode(bytes);
    stdout.writeln('  codec decode      ${sw.elapsedMilliseconds} ms'
        '  rss +${((rss() - before) / 1048576).toStringAsFixed(0)} MB');
    sw = Stopwatch()..start();
    final result = SurveyRowParser.parse(rows);
    stdout.writeln('  row parser        ${sw.elapsedMilliseconds} ms  points=${result.points.length}');
    sw = Stopwatch()..start();
    before = rss();
    final viaIsolate = await Isolate.run(() => parseWorkbook(bytes));
    stdout.writeln('  isolate total     ${sw.elapsedMilliseconds} ms (incl. spawn, copy in+out)'
        '  rss +${((rss() - before) / 1048576).toStringAsFixed(0)} MB  points=${viaIsolate.points.length}');
    // Cost of just shipping the parsed points to an isolate and back.
    sw = Stopwatch()..start();
    final echoed = await Isolate.run(() => result.points.length);
    stdout.writeln('  isolate noop+copy-in of points ${sw.elapsedMilliseconds} ms ($echoed)');
  }
}
