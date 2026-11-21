import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/core/platform/file_service.dart';
import 'package:survey_contour_generator/src/features/contour/data/xlsx_spreadsheet_codec.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/dxf_exporter.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/contour_controller.dart';

import '../../../../helpers/fakes.dart';

final _clock = DateTime.utc(2026, 3, 9, 23, 59);

Uint8List _book(List<List<CellValue?>> rows) {
  final wb = Excel.createExcel();
  final sheet = wb[wb.getDefaultSheet()!];
  rows.forEach(sheet.appendRow);
  return Uint8List.fromList(wb.encode()!);
}

TextCellValue _t(String s) => TextCellValue(s);
IntCellValue _i(int v) => IntCellValue(v);

class _Env {
  _Env({bool manual = false}) : runner = FakeComputeRunner(manual: manual) {
    controller = ContourController(
      files: files,
      printer: printer,
      runner: runner,
      clock: () => _clock,
      fitDelay: Duration.zero,
      toastDuration: const Duration(milliseconds: 20),
    );
  }

  final files = FakeFileService();
  final printer = FakePrintService();
  final FakeComputeRunner runner;
  late final ContourController controller;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late _Env env;
  late ContourController c;

  setUp(() {
    env = _Env();
    c = env.controller;
  });
  tearDown(() => c.dispose());

  test('defaults', () {
    expect(c.interval, 1.0);
    expect(c.majorEvery, 5);
    expect(c.smoothness, 0);
    expect(c.model.contours, isEmpty);
    expect(c.summary, isNull);
    expect(c.isComputing, isFalse);
    expect(c.fileLoading, isNull);
    expect(c.toast, isNull);
  });

  group('import', () {
    final good = _book([
      [_t('BH'), _t('X'), _t('Y'), _t('RL'), _t('Line')],
      [_t('A'), _i(0), _i(0), _i(10), null],
      [_t('B'), _i(10), _i(0), _i(12), null],
      [_t('C'), _i(0), _i(10), _i(11), null],
      [null, _i(1), _i(1), _i(10), _t('L')],
      [null, _i(2), _i(2), _i(11), _t('L')],
    ]);

    test('success sets data, stages and toast', () async {
      env.files.picked = pickedFromBytes('a.xlsx', good);
      final stages = <String>[];
      c.addListener(() {
        final s = c.fileLoading;
        if (s == null) return;
        final label = '${s.stage}@${s.progress}';
        if (stages.isEmpty || stages.last != label) stages.add(label);
      });
      await c.importSpreadsheet();
      await _settle();
      expect(stages, [
        'Reading file...@10',
        'Parsing Excel data...@30',
        'Processing sheets...@50',
        'Generating triangulation...@75',
        'Fitting view...@90',
      ]);
      expect(c.points.length, 3);
      expect(c.points.first.x, 0);
      expect(c.breakLines.single.name, 'L');
      expect(c.toast, '✓ Imported 3 points, 1 breaklines');
      expect(c.fileLoading, isNull);
      expect(c.model.triangles, isNotEmpty);
      expect(c.summary, isNotNull);
    });

    test('empty workbook shows warning', () async {
      env.files.picked = pickedFromBytes(
        'a.xlsx',
        _book([
          [_t('foo')],
          [_t('bar')],
        ]),
      );
      await c.importSpreadsheet();
      expect(c.toast, '⚠ No valid data found');
      expect(c.fileLoading, isNull);
    });

    test('corrupt file shows error', () async {
      env.files.picked = pickedFromBytes('a.xlsx', Uint8List.fromList([1, 2]));
      await c.importSpreadsheet();
      expect(c.toast, '✕ Error reading file');
      expect(c.fileLoading, isNull);
    });

    test('file over 20 MB is rejected before reading', () async {
      var read = false;
      env.files.picked = PickedFile(
        name: 'big.xlsx',
        size: maxSpreadsheetBytes + 1,
        readBytes: () async {
          read = true;
          return Uint8List(0);
        },
      );
      await c.importSpreadsheet();
      expect(read, isFalse);
      expect(c.toast, '✕ Error reading file');
    });

    test('cancelled pick changes nothing', () async {
      c.loadSample();
      await _settle();
      env.files.picked = null;
      await c.importSpreadsheet();
      expect(c.points.length, 12);
    });

    test('picker failure shows error', () async {
      env.files.pickError = StateError('boom');
      await c.importSpreadsheet();
      expect(c.toast, '✕ Error reading file');
    });

    test('previous data is cleared and reset callback fires', () async {
      c.loadSample();
      var resets = 0;
      c.onDataReset = () => resets++;
      env.files.picked = pickedFromBytes('a.xlsx', Uint8List.fromList([1]));
      await c.importSpreadsheet();
      expect(c.points, isEmpty);
      expect(resets, 1);
    });
  });

  group('recompute', () {
    test('computes model once at least 3 points exist', () async {
      c.loadSample();
      expect(c.isComputing, isTrue);
      await _settle();
      expect(c.isComputing, isFalse);
      expect(c.model.contours, isNotEmpty);
      expect(c.summary, isNotNull);
    });

    test('latest wins when results arrive out of order', () async {
      final m = _Env(manual: true);
      final mc = m.controller;
      mc.loadSample();
      mc.setInterval(2);
      mc.setInterval(0.5);
      expect(m.runner.pending.length, 3);
      m.runner.pending[2]();
      await _settle();
      final latest = mc.model.contours.length;
      expect(latest, greaterThan(0));
      m.runner.pending[0]();
      m.runner.pending[1]();
      await _settle();
      expect(mc.model.contours.length, latest);
      expect(mc.isComputing, isFalse);
      mc.dispose();
    });

    test('dropping below 3 points clears the model synchronously', () async {
      c.loadSample();
      await _settle();
      c.clear();
      expect(c.model.contours, isEmpty);
      expect(c.summary, isNull);
      expect(c.isComputing, isFalse);
      expect(c.toast, '✓ Cleared');
    });

    test('result after dispose is ignored', () async {
      final m = _Env(manual: true);
      m.controller.loadSample();
      m.controller.dispose();
      m.runner.pending.single();
      await _settle();
    });
  });

  group('parameters', () {
    test('interval validates and clamps', () {
      c.setInterval(double.nan);
      c.setInterval(-1);
      c.setInterval(0);
      expect(c.interval, 1.0);
      c.setInterval(0.01);
      expect(c.interval, ContourController.minInterval);
      c.setInterval(1e9);
      expect(c.interval, ContourController.maxInterval);
      c.setInterval(2.5);
      expect(c.interval, 2.5);
    });

    test('majorEvery clamps to 1..1000', () {
      c.setMajorEvery(0);
      expect(c.majorEvery, 1);
      c.setMajorEvery(5000);
      expect(c.majorEvery, 1000);
      c.setMajorEvery(7);
      expect(c.majorEvery, 7);
    });

    test('smoothness clamps to 0..10 and ignores NaN', () {
      c.setSmoothness(double.nan);
      expect(c.smoothness, 0);
      c.setSmoothness(99);
      expect(c.smoothness, 10);
      c.setSmoothness(-3);
      expect(c.smoothness, 0);
      c.setSmoothness(4.5);
      expect(c.smoothness, 4.5);
    });

    test('unchanged value does not notify', () {
      var n = 0;
      c.addListener(() => n++);
      c.setInterval(1.0);
      c.setMajorEvery(5);
      c.setSmoothness(0);
      expect(n, 0);
    });
  });

  group('breaklines', () {
    test('add names BL-n, delete and update', () async {
      c.addBreakLine(const [Point3(0, 0, 1), Point3(1, 1, 2)]);
      c.addBreakLine(const [Point3(2, 2, 1), Point3(3, 3, 2)]);
      expect(c.breakLines.map((b) => b.name), ['BL-1', 'BL-2']);
      expect(c.toast, '✓ Breakline added');

      c.updateBreakLinePoint(0, 1, const Point3(9, 9, 9));
      expect(c.breakLines[0].points[1].x, 9);
      c.updateBreakLinePoint(0, 5, const Point3(1, 1, 1));
      c.updateBreakLinePoint(5, 0, const Point3(1, 1, 1));
      c.updateBreakLinePoint(0, 0, const Point3(double.nan, 1, 1));
      expect(c.breakLines[0].points[0].x, 0);

      c.deleteBreakLine(0);
      expect(c.breakLines.single.name, 'BL-2');
      expect(c.toast, '✓ Deleted');
      c.deleteBreakLine(9);
      expect(c.breakLines.length, 1);
    });

    test('points editor toast', () {
      c.announceBreakLinePointsSaved();
      expect(c.toast, '✓ Breakline points saved');
    });
  });

  group('toast', () {
    test('auto clears and restarts on a new toast', () async {
      c.showToast('a');
      await Future<void>.delayed(const Duration(milliseconds: 12));
      c.showToast('b');
      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(c.toast, 'b');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.toast, isNull);
    });
  });

  group('exports', () {
    Future<void> loaded() async {
      c.loadSample();
      await _settle();
    }

    test('dxf uses fixed clock and domain exporter', () async {
      await loaded();
      expect(await c.exportDxf(), isTrue);
      final f = env.files.saved.single;
      expect(f.fileName, 'contour-2026-03-09-R12.dxf');
      expect(f.mimeType, 'application/dxf');
      expect(
        utf8.decode(f.bytes),
        DxfExporter.build(c.model.contours, c.breakLines, c.points),
      );
      expect(c.toast, '✓ DXF R12 exported (max compatibility)');
    });

    test('lsp and scr names, mime and toasts', () async {
      await loaded();
      expect(await c.exportAutoLisp(), isTrue);
      expect(env.files.saved.last.fileName, 'contour-2026-03-09.lsp');
      expect(env.files.saved.last.mimeType, 'text/plain');
      expect(
        utf8.decode(env.files.saved.last.bytes),
        contains('2026-03-09T23:59'),
      );
      expect(c.toast, '✓ AutoLISP exported');
      expect(await c.exportCivil3dScript(), isTrue);
      expect(env.files.saved.last.fileName, 'contour-2026-03-09.scr');
      expect(c.toast, '✓ Civil 3D script exported');
    });

    test('exports without points warn (dxf still exports)', () async {
      expect(await c.exportAutoLisp(), isFalse);
      expect(c.toast, '⚠ No survey points');
      expect(await c.exportCivil3dScript(), isFalse);
      expect(await c.saveImage(Uint8List(1), 'png'), isFalse);
      expect(await c.printPng(Uint8List(1)), isFalse);
      expect(env.files.saved, isEmpty);
      expect(await c.exportDxf(), isTrue);
    });

    test('breaklines xlsx', () async {
      expect(await c.exportBreaklinesXlsx(), isFalse);
      expect(c.toast, '⚠ No breaklines');
      c.addBreakLine(const [Point3(0, 0, 1), Point3(1, 1, 2)]);
      expect(await c.exportBreaklinesXlsx(), isTrue);
      final f = env.files.saved.single;
      expect(f.fileName, 'breaklines-2026-03-09.xlsx');
      expect(f.mimeType, XlsxSpreadsheetCodec.breaklinesMimeType);
      expect(const XlsxSpreadsheetCodec().decode(f.bytes).single.length, 2);
      expect(c.toast, '✓ Excel exported');
    });

    test('images', () async {
      await loaded();
      final png = Uint8List.fromList([1, 2, 3]);
      expect(await c.saveImage(png, 'png'), isTrue);
      expect(env.files.saved.last.fileName, 'contour-2026-03-09.png');
      expect(env.files.saved.last.mimeType, 'image/png');
      expect(env.files.saved.last.bytes, png);
      expect(c.toast, '✓ PNG image exported (3000x3000)');
      expect(await c.saveImage(png, 'bmp'), isTrue);
      expect(env.files.saved.last.fileName, 'contour-2026-03-09.bmp');
      expect(env.files.saved.last.mimeType, 'image/bmp');
      expect(c.toast, '✓ BMP image exported (3000x3000)');
    });

    test('print', () async {
      await loaded();
      final png = Uint8List.fromList([9]);
      expect(await c.printPng(png), isTrue);
      expect(env.printer.printed.single, png);
      expect(c.toast, '✓ Print dialog opened');
    });

    test(
      'cancelled save shows no success toast; errors show failure',
      () async {
        await loaded();
        c.showToast('x');
        env.files.saveResult = false;
        expect(await c.exportAutoLisp(), isFalse);
        expect(c.toast, 'x');
        env.files.saveError = StateError('disk');
        expect(await c.exportAutoLisp(), isFalse);
        expect(c.toast, startsWith('✕ Export failed: '));
      },
    );
  });
}
