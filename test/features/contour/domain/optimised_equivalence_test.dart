import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/contour.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/triangle.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_generator.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_model_builder.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/delaunay.dart';

import 'reference/reference_domain.dart';

/// Proves the optimised Delaunay / contour chain code is bit-for-bit identical
/// to the original straightforward algorithms on random inputs.
void main() {
  final shapes = <String, List<SurveyPoint> Function(math.Random, int)>{
    'uniform': _uniform,
    'jittered grid': _jitteredGrid,
    'integer lattice (many cocircular)': _lattice,
    'duplicates': _duplicates,
    'collinear': _collinear,
    'two clusters far apart': _clusters,
    'large offsets (UTM)': _utm,
  };

  group('Delaunay matches the reference implementation', () {
    for (final entry in shapes.entries) {
      for (final n in const [1, 2, 3, 4, 5, 7, 25, 150, 600, 2000]) {
        for (final seed in const [1, 2, 3]) {
          test('${entry.key} n=$n seed=$seed', () {
            final pts = entry.value(math.Random(seed * 7919 + n), n);
            expectSameTriangles(
              Delaunay.triangulate(pts),
              ReferenceDelaunay.triangulate(pts),
            );
          });
        }
      }
    }

    test('extreme aspect (two clusters 1e7 apart) n=120', () {
      final r = math.Random(5);
      final pts = [
        for (var i = 0; i < 120; i++)
          _pt(i, (i.isEven ? 0 : 1e7) + r.nextDouble() * 5,
              (i.isEven ? 0 : 1e7) + r.nextDouble() * 5, r.nextDouble()),
      ];
      expectSameTriangles(
        Delaunay.triangulate(pts),
        ReferenceDelaunay.triangulate(pts),
      );
    });

    test('non-finite coordinates fall back to the plain scan', () {
      final r = math.Random(8);
      final pts = [
        for (var i = 0; i < 300; i++)
          _pt(i, i == 7 ? double.nan : r.nextDouble() * 100,
              i == 11 ? double.infinity : r.nextDouble() * 100, r.nextDouble()),
      ];
      expectSameTriangles(
        Delaunay.triangulate(pts),
        ReferenceDelaunay.triangulate(pts),
      );
    });
  });

  group('grid-pruned bad sets equal a full scan at every insertion', () {
    // triangulateVerified throws if the candidate set ever differs from the
    // exhaustive scan, so large inputs are proven without a slow reference.
    for (final entry in shapes.entries) {
      for (final n in const [96, 300, 3000, 8000]) {
        // Clustered data degenerates the grid to a full scan (and the
        // verification doubles it), so keep those cases small.
        if (entry.key.contains('clusters') && n > 3000) continue;
        test('${entry.key} n=$n', () {
          final pts = entry.value(math.Random(n * 31 + 7), n);
          expectSameTriangles(
            Delaunay.triangulateVerified(pts),
            Delaunay.triangulate(pts),
          );
        });
      }
    }
  });

  group('mergeBreakLinePoints matches the linear-scan reference', () {
    List<SurveyPoint> reference(List<SurveyPoint> points, List<BreakLine> bls) {
      final merged = [...points];
      for (final bl in bls) {
        for (final pt in bl.points) {
          final exists = merged.any(
            (p) =>
                (p.x - pt.x).abs() < 0.001 && (p.y - pt.y).abs() < 0.001,
          );
          if (!exists) {
            merged.add(SurveyPoint(borehole: bl.name, x: pt.x, y: pt.y, z: pt.z));
          }
        }
      }
      return merged;
    }

    for (final seed in const [1, 2, 3, 4, 5, 6]) {
      test('random points, duplicates at the tolerance edge, seed $seed', () {
        final r = math.Random(seed);
        final offset = [0.0, 512345.678, -4123456.789, 1e9, -1e9, 3e12][seed - 1];
        final points = [
          for (var i = 0; i < 400; i++)
            _pt(i, offset + r.nextInt(40) * 0.5, offset - r.nextInt(40) * 0.5, 1),
        ];
        const deltas = [0.0, 0.0005, 0.000999, 0.001, 0.0010001, 0.002, -0.0009, -0.001];
        final bls = [
          for (var b = 0; b < 4; b++)
            BreakLine(name: 'B$b', points: [
              for (var i = 0; i < 300; i++)
                Point3(
                  points[r.nextInt(points.length)].x + deltas[r.nextInt(deltas.length)],
                  points[r.nextInt(points.length)].y + deltas[r.nextInt(deltas.length)],
                  r.nextDouble() * 9,
                ),
              if (seed == 4) ...[
                const Point3(double.nan, 1, 1),
                const Point3(double.infinity, 2, 1),
                const Point3(3, double.negativeInfinity, 1),
                const Point3(double.nan, 1, 1),
              ],
            ]),
        ];
        final actual = ContourModelBuilder.mergeBreakLinePoints(points, bls);
        final expected = reference(points, bls);
        expect(actual.length, expected.length);
        for (var i = 0; i < actual.length; i++) {
          expect(actual[i].borehole, expected[i].borehole);
          expect(actual[i].x.compareTo(expected[i].x), 0);
          expect(actual[i].y.compareTo(expected[i].y), 0);
          expect(actual[i].z, expected[i].z);
        }
      });
    }
  });

  group('ContourGenerator matches the reference implementation', () {
    for (final entry in shapes.entries) {
      for (final n in const [3, 12, 60, 400, 1500]) {
        for (final seed in const [1, 2]) {
          for (final interval in const [0.25, 1.0, 3.5]) {
            test('${entry.key} n=$n seed=$seed interval=$interval', () {
              final rnd = math.Random(seed * 104729 + n);
              final pts = [
                for (final p in entry.value(rnd, n))
                  // Mixed signs, including negative levels.
                  SurveyPoint(
                    borehole: p.borehole,
                    x: p.x,
                    y: p.y,
                    z: (rnd.nextDouble() - 0.6) * 40,
                  ),
              ];
              final tris = ReferenceDelaunay.triangulate(pts);
              final smooth = seed == 2 ? 3.0 : 0.0;
              final actual = ContourGenerator.generate(tris, interval, 5,
                  smoothness: smooth);
              final expected = ReferenceContourGenerator.generate(
                tris,
                interval,
                5,
                smoothness: smooth,
                smooth: ContourGenerator.smooth,
              );
              expectSameContours(actual, expected);
            });
          }
        }
      }
    }

    test('chain joining with near-coincident vertices and tolerance edge', () {
      // Hand-built triangles whose crossings fall within/at the 0.01 join
      // tolerance of one another.
      final rnd = math.Random(99);
      final tris = <Triangle>[];
      for (var i = 0; i < 400; i++) {
        SurveyPoint p(double x, double y, double z) =>
            SurveyPoint(borehole: 'p', x: x, y: y, z: z);
        final x = (rnd.nextInt(30)).toDouble();
        final y = (rnd.nextInt(30)).toDouble();
        final d = [0.0, 0.005, 0.0099999, 0.01, 0.0100001, 0.02][rnd.nextInt(6)];
        tris.add(Triangle(
          p(x, y, rnd.nextInt(4) - 1.0),
          p(x + 1 + d, y + d, rnd.nextInt(4) - 1.0),
          p(x, y + 1 - d, rnd.nextInt(4) - 1.0),
        ));
      }
      for (final interval in const [0.5, 1.0]) {
        expectSameContours(
          ContourGenerator.generate(tris, interval, 2),
          ReferenceContourGenerator.generate(tris, interval, 2),
        );
      }
    });
  });
}

void expectSameTriangles(List<Triangle> actual, List<Triangle> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < actual.length; i++) {
    // The very same SurveyPoint instances, in the same order.
    expect(identical(actual[i].p1, expected[i].p1), isTrue, reason: 'tri $i p1');
    expect(identical(actual[i].p2, expected[i].p2), isTrue, reason: 'tri $i p2');
    expect(identical(actual[i].p3, expected[i].p3), isTrue, reason: 'tri $i p3');
  }
}

void expectSameContours(List<Contour> actual, List<Contour> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].level, expected[i].level);
    expect(actual[i].isMajor, expected[i].isMajor);
    final a = actual[i].points, e = expected[i].points;
    expect(a.length, e.length, reason: 'contour $i length');
    for (var j = 0; j < a.length; j++) {
      expect(a[j].x, e[j].x, reason: 'contour $i point $j x');
      expect(a[j].y, e[j].y, reason: 'contour $i point $j y');
    }
  }
}

SurveyPoint _pt(int i, double x, double y, double z) =>
    SurveyPoint(borehole: 'P$i', x: x, y: y, z: z);

List<SurveyPoint> _uniform(math.Random r, int n) => [
      for (var i = 0; i < n; i++)
        _pt(i, r.nextDouble() * 1000, r.nextDouble() * 800, r.nextDouble() * 50),
    ];

List<SurveyPoint> _jitteredGrid(math.Random r, int n) {
  final side = math.sqrt(n).ceil();
  return [
    for (var i = 0; i < n; i++)
      _pt(i, (i % side) * 10 + r.nextDouble() * 6, (i ~/ side) * 10 + r.nextDouble() * 6,
          r.nextDouble() * 30),
  ];
}

List<SurveyPoint> _lattice(math.Random r, int n) {
  final side = math.sqrt(n).ceil();
  return [
    for (var i = 0; i < n; i++)
      _pt(i, (i % side).toDouble(), (i ~/ side).toDouble(), r.nextDouble() * 10),
  ];
}

List<SurveyPoint> _duplicates(math.Random r, int n) {
  final base = _uniform(r, math.max(1, n ~/ 3));
  return [
    for (var i = 0; i < n; i++)
      _pt(i, base[r.nextInt(base.length)].x, base[r.nextInt(base.length)].y,
          r.nextDouble() * 20),
  ];
}

List<SurveyPoint> _collinear(math.Random r, int n) => [
      for (var i = 0; i < n; i++)
        // Exactly collinear, with a few off-line outliers.
        i % 17 == 16
            ? _pt(i, r.nextDouble() * 100, r.nextDouble() * 100, r.nextDouble() * 9)
            : _pt(i, i.toDouble() * 2, i * 1.0 * 2 + 5, r.nextDouble() * 9),
    ];

List<SurveyPoint> _clusters(math.Random r, int n) => [
      for (var i = 0; i < n; i++)
        i.isEven
            ? _pt(i, r.nextDouble() * 5, r.nextDouble() * 5, r.nextDouble() * 9)
            : _pt(i, 1e5 + r.nextDouble() * 5, 1e5 + r.nextDouble() * 5,
                r.nextDouble() * 9),
    ];

List<SurveyPoint> _utm(math.Random r, int n) => [
      for (var i = 0; i < n; i++)
        _pt(i, 512345.123 + r.nextDouble() * 900, 4123456.789 + r.nextDouble() * 900,
            100 + r.nextDouble() * 30),
    ];
