import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/triangle.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_model_builder.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/contour_label_anchor.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/tin_visualizer_painter.dart';

import 'reference_tin_painter.dart';

/// Optimised painter/geometry internals must produce exactly the same output
/// as the straightforward implementations they replaced.
void main() {
  group('IndexedLabelAnchor == ContourLabelAnchor', () {
    for (final seed in const [1, 2, 3, 4, 5]) {
      test('random survey and contours, seed $seed', () {
        final r = math.Random(seed);
        final n = 1 + r.nextInt(600);
        final spread = [10.0, 1000.0, 1e5][seed % 3];
        final survey = [
          for (var i = 0; i < n; i++)
            SurveyPoint(
              borehole: 'P$i',
              // Clustered + uniform + some duplicates + a few non-finite.
              x: i == 3 && seed == 4
                  ? double.nan
                  : (i % 5 == 0 ? 50.0 : r.nextDouble() * spread),
              y: i == 4 && seed == 4
                  ? double.infinity
                  : (i % 5 == 0 ? 50.0 : r.nextDouble() * spread),
              z: 0,
            ),
        ];
        final indexed = IndexedLabelAnchor(survey);
        final clearance = ContourLabelAnchor.clearanceFor(survey);
        expect(indexed.clearance, clearance);
        for (var c = 0; c < 200; c++) {
          final len = 2 + r.nextInt(60);
          // Contours may leave the survey box (smoothing overshoot).
          final x0 = r.nextDouble() * spread * 1.4 - spread * 0.2;
          final y0 = r.nextDouble() * spread * 1.4 - spread * 0.2;
          final pts = [
            for (var i = 0; i < len; i++)
              Point2(x0 + i * spread / 80 * (r.nextBool() ? 1 : -1),
                  y0 + r.nextDouble() * spread / 20),
          ];
          expect(
            indexed.indexFor(pts),
            ContourLabelAnchor.indexFor(pts, survey, clearance),
          );
        }
      });
    }

    test('empty survey and zero clearance', () {
      final a = IndexedLabelAnchor(const []);
      final line = [for (var i = 0; i < 7; i++) Point2(i.toDouble(), 0)];
      expect(a.indexFor(line), 3);
    });
  });

  group('MapGeometry TIN paths are unchanged', () {
    test('edge order and shared/hull split match the original algorithm', () {
      final r = math.Random(11);
      final points = [
        for (var i = 0; i < 400; i++)
          SurveyPoint(
            borehole: 'P$i',
            x: r.nextDouble() * 500,
            y: r.nextDouble() * 400,
            z: r.nextDouble() * 20,
          ),
      ];
      final model = ContourModelBuilder.build(
        points: points,
        breakLines: const [],
        interval: 1,
        majorEvery: 5,
        smoothness: 0,
      );
      final geometry = MapGeometry.build(
        points: points,
        breakLines: const [],
        triangles: model.triangles,
        contours: model.contours,
      );
      final ref = _referenceTin(
        model.triangles,
        Offset(geometry.originX, geometry.originY),
      );
      _expectSamePath(geometry.tinShared, ref.shared);
      _expectSamePath(geometry.tinHull, ref.hull);
      geometry.dispose();
    });
  });

  group('TinVisualizerPainter pixels are unchanged', () {
    final r = math.Random(5);
    final points = [
      for (var i = 0; i < 80; i++)
        SurveyPoint(
          borehole: 'P$i',
          x: r.nextDouble() * 100,
          y: r.nextDouble() * 100,
          z: r.nextDouble() * 9,
        ),
    ];
    final model = ContourModelBuilder.build(
      points: points,
      breakLines: const [],
      interval: 1,
      majorEvery: 5,
      smoothness: 0,
    );
    final data = TinVisualData(
      points: points,
      triangles: model.triangles,
      breakLines: [
        BreakLine(
          name: 'B',
          points: const [Point3(5, 5, 1), Point3(60, 40, 2), Point3(90, 90, 3)],
        ),
      ],
      size: const Size(320, 280),
      expanded: false,
    );

    for (final t in const [null, 0.0, 0.2, 0.45, 0.7, 1.0]) {
      testWidgets('animation value $t', (tester) async {
        final animation =
            t == null ? null : AlwaysStoppedAnimation<double>(t);
        final actual = await _render(
          tester,
          TinVisualizerPainter(data: data, animation: animation),
        );
        final expected = await _render(
          tester,
          ReferenceTinVisualizerPainter(data: data, animation: animation),
        );
        if (t != 0.0) expect(actual.any((b) => b != 0), isTrue);
        expect(actual, expected);
      });
    }
  });
}

Future<List<int>> _render(WidgetTester tester, CustomPainter painter) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(320, 280));
    final picture = recorder.endRecording();
    final image = await picture.toImage(320, 280);
    final bytes = await image.toByteData();
    image.dispose();
    picture.dispose();
    return Uint8List.sublistView(bytes!);
  }))!;
}

({Path shared, Path hull}) _referenceTin(
  List<Triangle> triangles,
  Offset origin,
) {
  final index = Map<SurveyPoint, int>.identity();
  int idOf(SurveyPoint p) => index.putIfAbsent(p, () => index.length);
  final counts = <int, int>{};
  final edges = <(int, int, SurveyPoint, SurveyPoint)>[];
  for (final t in triangles) {
    final ids = [idOf(t.p1), idOf(t.p2), idOf(t.p3)];
    final pts = [t.p1, t.p2, t.p3];
    for (var k = 0; k < 3; k++) {
      final a = ids[k];
      final b = ids[(k + 1) % 3];
      final key = a < b ? a * 0x100000000 + b : b * 0x100000000 + a;
      counts[key] = (counts[key] ?? 0) + 1;
      edges.add((a, b, pts[k], pts[(k + 1) % 3]));
    }
  }
  final shared = Path();
  final hull = Path();
  final seen = <int>{};
  for (final e in edges) {
    final key = e.$1 < e.$2
        ? e.$1 * 0x100000000 + e.$2
        : e.$2 * 0x100000000 + e.$1;
    if (!seen.add(key)) continue;
    final target = (counts[key] ?? 1) > 1 ? shared : hull;
    target
      ..moveTo(e.$3.x - origin.dx, e.$3.y - origin.dy)
      ..lineTo(e.$4.x - origin.dx, e.$4.y - origin.dy);
  }
  return (shared: shared, hull: hull);
}

void _expectSamePath(Path actual, Path expected) {
  final a = actual.computeMetrics().toList();
  final e = expected.computeMetrics().toList();
  expect(a.length, e.length);
  for (var i = 0; i < a.length; i++) {
    expect(a[i].length, e[i].length, reason: 'sub-path $i');
    expect(
      a[i].getTangentForOffset(0)?.position,
      e[i].getTangentForOffset(0)?.position,
      reason: 'start of sub-path $i',
    );
    expect(
      a[i].getTangentForOffset(a[i].length)?.position,
      e[i].getTangentForOffset(e[i].length)?.position,
      reason: 'end of sub-path $i',
    );
  }
  expect(actual.getBounds(), expected.getBounds());
}
