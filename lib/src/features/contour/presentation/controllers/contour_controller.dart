// Named constructor parameters differ from the private fields on purpose.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/platform/compute_runner.dart';
import '../../../../core/platform/file_service.dart';
import '../../../../core/platform/print_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/xlsx_spreadsheet_codec.dart';
import '../../domain/entities/geometry.dart';
import '../../domain/entities/survey_import.dart';
import '../../domain/entities/terrain.dart';
import '../../domain/services/autolisp_exporter.dart';
import '../../domain/services/civil3d_script_exporter.dart';
import '../../domain/services/contour_model_builder.dart';
import '../../domain/services/dxf_exporter.dart';
import '../../domain/services/survey_row_parser.dart';
import '../../domain/services/terrain_analyzer.dart';

/// Progress of a spreadsheet import (overlay text and bar).
@immutable
final class FileLoadingState {
  const FileLoadingState({required this.stage, required this.progress});

  final String stage;
  final int progress;
}

/// Inputs of one model computation (sendable to an isolate).
@immutable
final class ModelRequest {
  const ModelRequest({
    required this.points,
    required this.breakLines,
    required this.interval,
    required this.majorEvery,
    required this.smoothness,
  });

  final List<SurveyPoint> points;
  final List<BreakLine> breakLines;
  final double interval;
  final int majorEvery;
  final double smoothness;
}

/// Result of one model computation.
@immutable
final class ModelResult {
  const ModelResult(this.model, this.summary);

  final ContourModel model;
  final TerrainSummary? summary;
}

/// Top-level so it can run in an isolate.
ModelResult computeModel(ModelRequest r) {
  final model = ContourModelBuilder.build(
    points: r.points,
    breakLines: r.breakLines,
    interval: r.interval,
    majorEvery: r.majorEvery,
    smoothness: r.smoothness,
  );
  return ModelResult(
    model,
    TerrainAnalyzer.summarize(model.stats, r.breakLines, model.contours),
  );
}

/// Top-level so it can run in an isolate.
SurveyImportResult parseWorkbook(Uint8List bytes) =>
    SurveyRowParser.parse(const XlsxSpreadsheetCodec().decode(bytes));

/// Survey data, contour parameters, derived model, import/export and toasts.
class ContourController extends ChangeNotifier {
  ContourController({
    required FileService files,
    required PrintService printer,
    required ComputeRunner runner,
    DateTime Function() clock = DateTime.now,
    Duration toastDuration = const Duration(milliseconds: 2500),
    Duration fitDelay = const Duration(milliseconds: 300),
    XlsxSpreadsheetCodec codec = const XlsxSpreadsheetCodec(),
  }) : _files = files,
       _printer = printer,
       _runner = runner,
       _clock = clock,
       _toastDuration = toastDuration,
       _fitDelay = fitDelay,
       _codec = codec;

  static const double minInterval = 0.1;
  static const double maxInterval = 10000;
  static const int minMajorEvery = 1;
  static const int maxMajorEvery = 1000;
  static const double minSmoothness = 0;
  static const double maxSmoothness = 10;

  final FileService _files;
  final PrintService _printer;
  final ComputeRunner _runner;
  final DateTime Function() _clock;
  final Duration _toastDuration;
  final Duration _fitDelay;
  final XlsxSpreadsheetCodec _codec;

  List<SurveyPoint> _points = const [];
  List<BreakLine> _breakLines = const [];
  double _interval = 1.0;
  int _majorEvery = 5;
  double _smoothness = 0;
  ContourModel _model = ContourModel.empty;
  TerrainSummary? _summary;
  bool _isComputing = false;
  FileLoadingState? _fileLoading;
  String? _toast;
  Timer? _toastTimer;
  int _computeSeq = 0;
  bool _disposed = false;

  /// Called whenever loaded data is discarded or replaced (import start,
  /// sample, clear) so the view layer can reset drawing state and the view.
  VoidCallback? onDataReset;

  List<SurveyPoint> get points => _points;
  List<BreakLine> get breakLines => _breakLines;
  double get interval => _interval;
  int get majorEvery => _majorEvery;
  double get smoothness => _smoothness;
  ContourModel get model => _model;
  TerrainSummary? get summary => _summary;
  bool get isComputing => _isComputing;
  FileLoadingState? get fileLoading => _fileLoading;
  String? get toast => _toast;

  // ---- parameters ---------------------------------------------------------

  /// Ignores non-finite or non-positive values; clamps to 0.1 .. 10000.
  void setInterval(double value) {
    if (!value.isFinite || value <= 0) return;
    final v = value.clamp(minInterval, maxInterval);
    if (v == _interval) return;
    _interval = v;
    _recompute();
  }

  /// Clamps to 1 .. 1000.
  void setMajorEvery(int value) {
    final v = value.clamp(minMajorEvery, maxMajorEvery);
    if (v == _majorEvery) return;
    _majorEvery = v;
    _recompute();
  }

  /// Ignores NaN; clamps to 0 .. 10.
  void setSmoothness(double value) {
    if (value.isNaN) return;
    final v = value.clamp(minSmoothness, maxSmoothness);
    if (v == _smoothness) return;
    _smoothness = v;
    _recompute();
  }

  // ---- data ---------------------------------------------------------------

  void loadSample() {
    _points = List.unmodifiable(_samplePoints);
    _breakLines = const [];
    onDataReset?.call();
    _recompute();
    showToast('✓ Sample loaded');
  }

  void clear() {
    _points = const [];
    _breakLines = const [];
    onDataReset?.call();
    _recompute();
    showToast('✓ Cleared');
  }

  /// Appends a breakline named `BL-n` (n = count + 1).
  void addBreakLine(List<Point3> points) {
    final name = 'BL-${_breakLines.length + 1}';
    _breakLines = List.unmodifiable([
      ..._breakLines,
      BreakLine(name: name, points: List.unmodifiable(points)),
    ]);
    _recompute();
    showToast('✓ Breakline added');
  }

  void deleteBreakLine(int index) {
    if (index < 0 || index >= _breakLines.length) return;
    _breakLines = List.unmodifiable([
      for (var i = 0; i < _breakLines.length; i++)
        if (i != index) _breakLines[i],
    ]);
    _recompute();
    showToast('✓ Deleted');
  }

  /// Replaces vertex [pointIndex] of breakline [breakLineIndex]. Ignores
  /// invalid indices and non-finite coordinates.
  void updateBreakLinePoint(int breakLineIndex, int pointIndex, Point3 value) {
    if (breakLineIndex < 0 || breakLineIndex >= _breakLines.length) return;
    final bl = _breakLines[breakLineIndex];
    if (pointIndex < 0 || pointIndex >= bl.points.length) return;
    if (!value.x.isFinite || !value.y.isFinite || !value.z.isFinite) return;
    final pts = [...bl.points];
    pts[pointIndex] = value;
    final lines = [..._breakLines];
    lines[breakLineIndex] = BreakLine(
      name: bl.name,
      points: List.unmodifiable(pts),
    );
    _breakLines = List.unmodifiable(lines);
    _recompute();
  }

  /// Toast of the breakline point editor's "Done" button.
  void announceBreakLinePointsSaved() => showToast('✓ Breakline points saved');

  // ---- import -------------------------------------------------------------

  /// Picks and imports an Excel workbook. Same stages and toasts as the web
  /// app; replaces the current data.
  Future<void> importSpreadsheet() async {
    final PickedFile? file;
    try {
      file = await _files.pickSpreadsheet();
    } on Object catch (e, s) {
      AppLogger.error('pick failed', e, s);
      showToast('✕ Error reading file');
      return;
    }
    if (file == null || _disposed) return;

    _setLoading('Reading file...', 10);
    _points = const [];
    _breakLines = const [];
    onDataReset?.call();
    _recompute();

    try {
      final result = await _readWorkbook(file);
      if (_disposed) return;
      await _applyImport(result);
    } on Object catch (e, s) {
      AppLogger.error('import failed', e, s);
      _clearLoading();
      showToast('✕ Error reading file');
    }
  }

  Future<SurveyImportResult> _readWorkbook(PickedFile file) async {
    if (file.size > maxSpreadsheetBytes) {
      throw const SpreadsheetException('File too large');
    }
    _setLoading('Parsing Excel data...', 30);
    final bytes = await file.readBytes();
    if (bytes.length > maxSpreadsheetBytes) {
      throw const SpreadsheetException('File too large');
    }
    _setLoading('Processing sheets...', 50);
    return _runner.run(parseWorkbook, bytes);
  }

  Future<void> _applyImport(SurveyImportResult result) async {
    _setLoading('Generating triangulation...', 75);
    if (result.isEmpty) {
      _clearLoading();
      showToast('⚠ No valid data found');
      return;
    }
    _points = List.unmodifiable(result.points);
    _breakLines = List.unmodifiable(result.breakLines);
    _recompute();
    _setLoading('Fitting view...', 90);
    await Future<void>.delayed(_fitDelay);
    if (_disposed) return;
    _clearLoading();
    showToast(
      result.truncated
          ? '⚠ Too many rows: imported the first '
                '${result.points.length} points (limit reached)'
          : '✓ Imported ${result.points.length} points, '
                '${result.breakLines.length} breaklines',
    );
  }

  void _setLoading(String stage, int progress) {
    _fileLoading = FileLoadingState(stage: stage, progress: progress);
    _notify();
  }

  void _clearLoading() {
    _fileLoading = null;
    _notify();
  }

  // ---- export -------------------------------------------------------------

  /// Returns true when the file was saved (callers close the export dialog).
  Future<bool> exportDxf() => _guarded(
    requirePoints: false,
    fileName: 'contour-${_dateStamp()}-R12.dxf',
    mimeType: 'application/dxf',
    successToast: '✓ DXF R12 exported (max compatibility)',
    build: () =>
        utf8.encode(DxfExporter.build(_model.contours, _breakLines, _points)),
  );

  Future<bool> exportAutoLisp() => _guarded(
    fileName: 'contour-${_dateStamp()}.lsp',
    mimeType: 'text/plain',
    successToast: '✓ AutoLISP exported',
    build: () => utf8.encode(
      AutoLispExporter.build(
        _model.contours,
        _breakLines,
        _points,
        generatedAt: _clock(),
      ),
    ),
  );

  Future<bool> exportCivil3dScript() => _guarded(
    fileName: 'contour-${_dateStamp()}.scr',
    mimeType: 'text/plain',
    successToast: '✓ Civil 3D script exported',
    build: () => utf8.encode(
      Civil3dScriptExporter.build(_model.contours, _breakLines, _points),
    ),
  );

  Future<bool> exportBreaklinesXlsx() async {
    if (_breakLines.isEmpty) {
      showToast('⚠ No breaklines');
      return false;
    }
    try {
      final saved = await _files.saveFile(
        fileName: 'breaklines-${_dateStamp()}.xlsx',
        bytes: _codec.encodeBreaklines(_breakLines),
        mimeType: XlsxSpreadsheetCodec.breaklinesMimeType,
      );
      if (saved) showToast('✓ Excel exported');
      return saved;
    } on Object catch (e, s) {
      AppLogger.error('xlsx export failed', e, s);
      showToast('✕ Export failed: $e');
      return false;
    }
  }

  /// Saves an already rendered image. [format] is `png` or `bmp`.
  Future<bool> saveImage(Uint8List bytes, String format) {
    final bmp = format == 'bmp';
    final label = bmp ? 'BMP' : 'PNG';
    return _guarded(
      fileName: 'contour-${_dateStamp()}.${bmp ? 'bmp' : 'png'}',
      mimeType: bmp ? 'image/bmp' : 'image/png',
      successToast: '✓ $label image exported (3000x3000)',
      build: () => bytes,
    );
  }

  Future<bool> printPng(Uint8List bytes) async {
    if (_points.isEmpty) {
      showToast('⚠ No survey points');
      return false;
    }
    try {
      await _printer.printPng(bytes);
      showToast('✓ Print dialog opened');
      return true;
    } on Object catch (e, s) {
      AppLogger.error('print failed', e, s);
      showToast('✕ Export failed: $e');
      return false;
    }
  }

  Future<bool> _guarded({
    required String fileName,
    required String mimeType,
    required String successToast,
    required List<int> Function() build,
    bool requirePoints = true,
  }) async {
    if (requirePoints && _points.isEmpty) {
      showToast('⚠ No survey points');
      return false;
    }
    try {
      final saved = await _files.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(build()),
        mimeType: mimeType,
      );
      if (saved) showToast(successToast);
      return saved;
    } on Object catch (e, s) {
      AppLogger.error('export failed', e, s);
      showToast('✕ Export failed: $e');
      return false;
    }
  }

  /// UTC date as `YYYY-MM-DD` (JavaScript `toISOString().slice(0, 10)`).
  String _dateStamp() => _clock().toUtc().toIso8601String().substring(0, 10);

  // ---- toast --------------------------------------------------------------

  /// Shows [message] and clears it after 2500 ms (a new toast restarts the
  /// timer).
  void showToast(String message) {
    _toast = message;
    _toastTimer?.cancel();
    _toastTimer = Timer(_toastDuration, () {
      _toast = null;
      _notify();
    });
    _notify();
  }

  // ---- recompute ----------------------------------------------------------

  /// Latest-wins: results of superseded computations are dropped.
  void _recompute() {
    final seq = ++_computeSeq;
    if (_points.length < 3) {
      _model = ContourModel.empty;
      _summary = null;
      _isComputing = false;
      _notify();
      return;
    }
    _isComputing = true;
    _notify();
    final request = ModelRequest(
      points: _points,
      breakLines: _breakLines,
      interval: _interval,
      majorEvery: _majorEvery,
      smoothness: _smoothness,
    );
    unawaited(_runCompute(seq, request));
  }

  Future<void> _runCompute(int seq, ModelRequest request) async {
    ModelResult? result;
    try {
      result = await _runner.run(computeModel, request);
    } on Object catch (e, s) {
      AppLogger.error('compute failed', e, s);
    }
    if (_disposed || seq != _computeSeq) return;
    _model = result?.model ?? ContourModel.empty;
    _summary = result?.summary;
    _isComputing = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _toastTimer?.cancel();
    super.dispose();
  }

  static const List<SurveyPoint> _samplePoints = [
    SurveyPoint(borehole: 'BH-001', x: 100, y: 100, z: 95.5),
    SurveyPoint(borehole: 'BH-002', x: 150, y: 120, z: 97.2),
    SurveyPoint(borehole: 'BH-003', x: 200, y: 100, z: 99.8),
    SurveyPoint(borehole: 'BH-004', x: 120, y: 180, z: 96.1),
    SurveyPoint(borehole: 'BH-005', x: 180, y: 180, z: 98.4),
    SurveyPoint(borehole: 'BH-006', x: 100, y: 250, z: 94.2),
    SurveyPoint(borehole: 'BH-007', x: 150, y: 250, z: 95.8),
    SurveyPoint(borehole: 'BH-008', x: 200, y: 250, z: 97.5),
    SurveyPoint(borehole: 'BH-009', x: 250, y: 150, z: 101.2),
    SurveyPoint(borehole: 'BH-010', x: 250, y: 220, z: 100.0),
    SurveyPoint(borehole: 'BH-011', x: 75, y: 175, z: 93.5),
    SurveyPoint(borehole: 'BH-012', x: 275, y: 175, z: 102.5),
  ];
}
