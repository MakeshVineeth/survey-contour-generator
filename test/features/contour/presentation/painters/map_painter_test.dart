import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/chart_data.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/chart_math.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_export_painter.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_painter.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/tin_visualizer_painter.dart';

import '../../../../helpers/map_harness.dart';

const _layers = MapLayers(
  tin: true,
  contours: true,
  breakLines: true,
  labels: true,
);

const _breakLine = BreakLine(
  name: 'BL-1',
  points: [Point3(110, 110, 96), Point3(190, 200, 98), Point3(120, 240, 95)],
);

void _paintOnce(CustomPainterLike painter, Size size) {
  final recorder = PictureRecorder();
  painter(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

typedef CustomPainterLike = void Function(Canvas canvas, Size size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapPainter', () {
    test('paints data, drawing line and empty state without errors', () {
      final model = sampleModel(breakLines: const [_breakLine]);
      expect(model.triangles, isNotEmpty);
      expect(model.contours, isNotEmpty);
      final geometry = MapGeometry.build(
        points: samplePoints,
        breakLines: const [_breakLine],
        triangles: model.triangles,
        contours: model.contours,
      );
      final painter = MapPainter(
        geometry: geometry,
        centerX: 150,
        centerY: 175,
        scale: 2,
        layers: _layers,
        drawMode: true,
        currentBreakline: const [Point3(120, 120, 96.5), Point3(130, 150, 97)],
      );
      _paintOnce(painter.paint, const Size(800, 600));
      // Zoomed far out / in and with layers hidden.
      for (final scale in [0.001, 0.02, 10000.0]) {
        _paintOnce(
          MapPainter(
            geometry: geometry,
            centerX: 150,
            centerY: 175,
            scale: scale,
            layers: const MapLayers(
              tin: false,
              contours: false,
              breakLines: false,
              labels: false,
            ),
            drawMode: false,
            currentBreakline: const [],
          ).paint,
          const Size(320, 568),
        );
      }
      geometry.dispose();

      final empty = MapGeometry.build(
        points: const [],
        breakLines: const [],
        triangles: const [],
        contours: const [],
      );
      _paintOnce(
        MapPainter(
          geometry: empty,
          centerX: 0,
          centerY: 0,
          scale: 1,
          layers: _layers,
          drawMode: false,
          currentBreakline: const [],
        ).paint,
        const Size(800, 600),
      );
      empty.dispose();
    });

    test('shouldRepaint only reacts to real changes', () {
      final model = sampleModel();
      final g = MapGeometry.build(
        points: samplePoints,
        breakLines: const [],
        triangles: model.triangles,
        contours: model.contours,
      );
      MapPainter make({double scale = 1, MapLayers layers = _layers}) =>
          MapPainter(
            geometry: g,
            centerX: 0,
            centerY: 0,
            scale: scale,
            layers: layers,
            drawMode: false,
            currentBreakline: const [],
          );
      expect(make().shouldRepaint(make()), isFalse);
      expect(make().shouldRepaint(make(scale: 2)), isTrue);
      expect(
        make().shouldRepaint(
          make(
            layers: const MapLayers(
              tin: false,
              contours: true,
              breakLines: true,
              labels: true,
            ),
          ),
        ),
        isTrue,
      );
      g.dispose();
    });

    test('geometry keeps survey-scale precision for large coordinates', () {
      const base = 500000.0;
      final pts = [
        for (final p in samplePoints)
          SurveyPoint(
            borehole: p.borehole,
            x: p.x + base,
            y: p.y + base,
            z: p.z,
          ),
      ];
      final g = MapGeometry.build(
        points: pts,
        breakLines: const [],
        triangles: const [],
        contours: const [],
      );
      // Relative positions stay small, so float32 paths keep sub-mm detail.
      expect(
        g.pointRel.every((o) => o.dx.abs() < 100 && o.dy.abs() < 100),
        isTrue,
      );
      g.dispose();
    });
  });

  group('exports', () {
    test('image and print renderings run', () {
      final model = sampleModel(breakLines: const [_breakLine]);
      final data = MapExportData(
        points: samplePoints,
        breakLines: const [_breakLine],
        triangles: model.triangles,
        contours: model.contours,
        layers: _layers,
      );
      _paintOnce(
        (c, s) => MapExportPainter.paintImage(c, 300, data),
        const Size(300, 300),
      );
      _paintOnce(
        (c, s) => MapExportPainter.paintPrint(
          c,
          200,
          data,
          generatedAt: DateTime(2026, 3, 7, 16, 5, 9),
        ),
        const Size(200, 200),
      );
      // No data must not produce NaN transforms or throw.
      const none = MapExportData(
        points: [],
        breakLines: [],
        triangles: [],
        contours: [],
        layers: _layers,
      );
      _paintOnce(
        (c, s) => MapExportPainter.paintImage(c, 100, none),
        const Size(100, 100),
      );
    });

    test('print date uses the en-US toLocaleString layout', () {
      expect(
        MapExportPainter.formatLocaleDateTime(DateTime(2026, 3, 7, 16, 5, 9)),
        '3/7/2026, 4:05:09 PM',
      );
      expect(
        MapExportPainter.formatLocaleDateTime(DateTime(2026, 12, 25, 0, 0, 0)),
        '12/25/2026, 12:00:00 AM',
      );
    });
  });

  group('chart helpers', () {
    test('slope bins classify with the larger edge slope', () {
      final model = sampleModel();
      final a = SlopeAnalysis.fromTriangles(model.triangles);
      expect(a.total, model.triangles.length);
      expect(a.bins.fold<int>(0, (s, b) => s + b.count), a.total);
      expect(a.max, greaterThanOrEqualTo(a.min));
    });

    test('sortedElevations is ascending and stable', () {
      final s = sortedElevations(const [
        SurveyPoint(borehole: 'a', x: 0, y: 0, z: 2),
        SurveyPoint(borehole: 'b', x: 0, y: 0, z: 1),
        SurveyPoint(borehole: 'c', x: 0, y: 0, z: 2),
      ]);
      expect([for (final e in s) e.name], ['b', 'a', 'c']);
    });

    test('nice axis intervals', () {
      expect(ChartMath.niceInterval(0.7), 0.5);
      expect(ChartMath.niceInterval(1.9), 2);
      expect(ChartMath.niceInterval(2.4), 2.5);
      expect(ChartMath.niceInterval(7), 5);
      expect(ChartMath.niceInterval(8), 10);
      final axis = ChartMath.valueAxis(94.2, 99.8, 150);
      expect(axis.min, lessThanOrEqualTo(94.2));
      expect(axis.max, greaterThanOrEqualTo(99.8));
      expect(axis.ticks.length, greaterThan(1));
    });

    test('anime easings hit their end points', () {
      expect(TinEasing.outElastic(0), 0);
      expect(TinEasing.outElastic(1), 1);
      expect(TinEasing.inOutQuad(0.5), closeTo(0.5, 1e-12));
      expect(TinEasing.inOutSine(1), closeTo(1, 1e-12));
      final tl = TinTimeline(pointCount: 18, triangleCount: 20, edgeCount: 3);
      expect(tl.totalMs, greaterThan(TinTimeline.pulseStart));
    });
  });
}
