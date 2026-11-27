// ignore_for_file: prefer_final_locals
// Run: flutter test tool/bench/paint_bench_test.dart
//
// Measures Dart-side cost (recording into a PictureRecorder, no rasterisation)
// of the heavy presentation paths at 1k / 5k / 20k points. JIT numbers: use
// them for before/after comparison, not as absolute device timings.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_model_builder.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/chart_data.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/elevation_chart_painter.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_export_painter.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_painter.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/tin_visualizer_painter.dart';

import 'bench_data.dart';

int _rss() => ProcessInfo.currentRss;

double _ms(Stopwatch sw) => sw.elapsedMicroseconds / 1000;

/// Runs [body] [reps] times and reports the best time.
double _best(int reps, void Function() body) {
  var best = double.infinity;
  for (var i = 0; i < reps; i++) {
    final sw = Stopwatch()..start();
    body();
    final t = _ms(sw);
    if (t < best) best = t;
  }
  return best;
}

void _record(void Function(Canvas) draw) {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final n in const [1000, 5000, 20000]) {
    test('paint bench n=$n', () {
      final out = StringBuffer('== n=$n\n');
      final points = generateSurvey(n);
      var sw = Stopwatch()..start();
      final model = ContourModelBuilder.build(
        points: points,
        breakLines: const [],
        interval: 0.5,
        majorEvery: 5,
        smoothness: 0,
      );
      out.writeln('  model build            ${_ms(sw).toStringAsFixed(0)} ms');

      var before = _rss();
      sw = Stopwatch()..start();
      final geometry = MapGeometry.build(
        points: points,
        breakLines: const [],
        triangles: model.triangles,
        contours: model.contours,
      );
      out.writeln('  MapGeometry.build      ${_ms(sw).toStringAsFixed(0)} ms'
          '  rss +${((_rss() - before) / 1048576).toStringAsFixed(0)} MB');

      final cx = geometry.originX, cy = geometry.originY;
      final fitScale = 700 / (n <= 1000 ? 330 : (n <= 5000 ? 720 : 1430));
      for (final labels in [false, true]) {
        final layers = MapLayers(tin: true, contours: true, breakLines: true, labels: labels);
        for (final scaleMul in const [1.0, 8.0]) {
          // First paint creates lazily cached labels; time it separately.
          sw = Stopwatch()..start();
          final rssBefore = _rss();
          _record((c) => MapPainter(
                geometry: geometry,
                centerX: cx,
                centerY: cy,
                scale: fitScale * scaleMul,
                layers: layers,
                drawMode: false,
                currentBreakline: const [],
              ).paint(c, const Size(1000, 700)));
          final first = _ms(sw);
          final firstRss = (_rss() - rssBefore) / 1048576;
          final warm = _best(5, () {
            _record((c) => MapPainter(
                  geometry: geometry,
                  centerX: cx,
                  centerY: cy,
                  scale: fitScale * scaleMul,
                  layers: layers,
                  drawMode: false,
                  currentBreakline: const [],
                ).paint(c, const Size(1000, 700)));
          });
          out.writeln('  MapPainter labels=$labels x$scaleMul   first ${first.toStringAsFixed(1)} ms (rss +${firstRss.toStringAsFixed(0)} MB)'
              '  warm ${warm.toStringAsFixed(1)} ms');
        }
      }
      geometry.dispose();

      sw = Stopwatch()..start();
      final samples = sortedElevations(points);
      out.writeln('  sortedElevations       ${_ms(sw).toStringAsFixed(1)} ms');
      sw = Stopwatch()..start();
      SlopeAnalysis.fromTriangles(model.triangles);
      out.writeln('  SlopeAnalysis          ${_ms(sw).toStringAsFixed(1)} ms');

      for (final style in [ElevationChartStyle.compact, ElevationChartStyle.large]) {
        final size = Size(style.expanded ? 900 : 320, style.height);
        final t = _best(5, () {
          _record((c) => ElevationChartPainter(samples: samples, style: style).paint(c, size));
        });
        final h = _best(5, () {
          _record((c) => ElevationChartPainter(samples: samples, style: style, hoverIndex: n ~/ 2)
              .paint(c, size));
        });
        final l = _best(5, () => ElevationChartLayout(size, samples, style));
        out.writeln('  ElevationChart ${style.expanded ? 'large ' : 'compact'}  paint ${t.toStringAsFixed(1)} ms'
            '  paint+hover ${h.toStringAsFixed(1)} ms  layout(hit-test) ${l.toStringAsFixed(2)} ms');
      }

      sw = Stopwatch()..start();
      final tin = TinVisualData(
        points: points,
        triangles: model.triangles,
        breakLines: const [],
        size: const Size(320, 280),
        expanded: false,
      );
      out.writeln('  TinVisualData          ${_ms(sw).toStringAsFixed(1)} ms');
      final staticT = _best(3, () => _record((c) => TinVisualizerPainter(data: tin).paint(c, const Size(320, 280))));
      final ctl = const AlwaysStoppedAnimation<double>(0.45);
      final animT = _best(3, () => _record((c) => TinVisualizerPainter(data: tin, animation: ctl).paint(c, const Size(320, 280))));
      out.writeln('  TinPainter static ${staticT.toStringAsFixed(1)} ms  mid-animation ${animT.toStringAsFixed(1)} ms');

      final data = MapExportData(
        points: points,
        breakLines: const [],
        triangles: model.triangles,
        contours: model.contours,
        layers: const MapLayers(tin: true, contours: true, breakLines: true, labels: false),
      );
      before = _rss();
      final exp = _best(2, () => _record((c) => MapExportPainter.paintImage(c, 3000, data)));
      out.writeln('  Export paintImage (no labels) ${exp.toStringAsFixed(0)} ms');
      if (n <= 5000) {
        final dataL = MapExportData(
          points: points,
          breakLines: const [],
          triangles: model.triangles,
          contours: model.contours,
          layers: const MapLayers(tin: true, contours: true, breakLines: true, labels: true),
        );
        final expL = _best(1, () => _record((c) => MapExportPainter.paintImage(c, 3000, dataL)));
        out.writeln('  Export paintImage (labels)    ${expL.toStringAsFixed(0)} ms');
      }
      // ignore: avoid_print
      print(out);
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
