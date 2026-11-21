import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/core/utils/js_number.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/terrain.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/autolisp_exporter.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/civil3d_script_exporter.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_model_builder.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/dxf_exporter.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/terrain_analyzer.dart';

/// Verifies the Dart domain against golden output produced by the original
/// JavaScript (regenerate with `node tool/gen_parity_fixtures.js`).
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (fixture['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  group('number formatting matches JavaScript toFixed', () {
    final fixed = (fixture['toFixedCases'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final c in fixed) {
      final v = (c['v'] as num).toDouble();
      test('value $v', () {
        expect(v.toFixed(0), c['f0'], reason: 'toFixed(0)');
        expect(v.toFixed(1), c['f1'], reason: 'toFixed(1)');
        expect(v.toFixed(2), c['f2'], reason: 'toFixed(2)');
        expect(v.toFixed(3), c['f3'], reason: 'toFixed(3)');
      });
    }
  });

  for (final c in cases) {
    group('case ${c['name']}', () {
      final points = (c['points'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (p) => SurveyPoint(
              borehole: p['borehole'] as String,
              x: (p['x'] as num).toDouble(),
              y: (p['y'] as num).toDouble(),
              z: (p['z'] as num).toDouble(),
            ),
          )
          .toList();
      final breakLines = (c['breakLines'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (b) => BreakLine(
              name: b['name'] as String,
              points: (b['points'] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .map(
                    (p) => Point3(
                      (p['x'] as num).toDouble(),
                      (p['y'] as num).toDouble(),
                      (p['z'] as num).toDouble(),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();

      final model = ContourModelBuilder.build(
        points: points,
        breakLines: breakLines,
        interval: (c['interval'] as num).toDouble(),
        majorEvery: (c['majorEvery'] as num).toInt(),
        smoothness: (c['smoothness'] as num).toDouble(),
      );

      test('triangulation is identical', () {
        expect(model.allPoints.length, c['allPointCount']);
        final index = Map<SurveyPoint, int>.identity();
        for (var i = 0; i < model.allPoints.length; i++) {
          index[model.allPoints[i]] = i;
        }
        final actual = [
          for (final t in model.triangles)
            [index[t.p1], index[t.p2], index[t.p3]],
        ];
        expect(actual, c['triangles']);
      });

      test('contours are identical', () {
        final expected = (c['contours'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(model.contours.length, expected.length);
        for (var i = 0; i < expected.length; i++) {
          final e = expected[i];
          final a = model.contours[i];
          expect(a.level, closeTo((e['level'] as num).toDouble(), 1e-12));
          expect(a.isMajor, e['isMajor']);
          final ep = (e['points'] as List<dynamic>).cast<List<dynamic>>();
          expect(a.points.length, ep.length, reason: 'contour $i vertex count');
          for (var j = 0; j < ep.length; j++) {
            expect(a.points[j].x, closeTo((ep[j][0] as num).toDouble(), 1e-9));
            expect(a.points[j].y, closeTo((ep[j][1] as num).toDouble(), 1e-9));
          }
        }
      });

      test('terrain statistics are identical', () {
        final e = c['stats'] as Map<String, dynamic>;
        final s = model.stats!;
        final elev = e['elevation'] as Map<String, dynamic>;
        final slope = e['slope'] as Map<String, dynamic>;
        final dist = e['slopeDistribution'] as Map<String, dynamic>;
        expect(s.area, closeTo((e['area'] as num).toDouble(), 1e-6));
        expect(s.pointCount, e['pointCount']);
        expect(s.triangleCount, e['triangleCount']);
        expect(s.elevation.min, (elev['min'] as num).toDouble());
        expect(s.elevation.max, (elev['max'] as num).toDouble());
        expect(s.elevation.avg, closeTo((elev['avg'] as num).toDouble(), 1e-9));
        expect(
          s.slope.avgDeg,
          closeTo((slope['avgDeg'] as num).toDouble(), 1e-9),
        );
        expect(
          s.slope.maxDeg,
          closeTo((slope['maxDeg'] as num).toDouble(), 1e-9),
        );
        expect(s.slopeDistribution.flat, dist['flat']);
        expect(s.slopeDistribution.gentle, dist['gentle']);
        expect(s.slopeDistribution.moderate, dist['moderate']);
        expect(s.slopeDistribution.steep, dist['steep']);
        expect(s.slopeDistribution.extreme, dist['extreme']);
        expect(s.terrainType.name, e['terrainType']);
        expect(s.terrainType, isA<TerrainType>());
      });

      test('summary text is identical', () {
        final e = c['summary'] as Map<String, dynamic>;
        final s = TerrainAnalyzer.summarize(
          model.stats,
          breakLines,
          model.contours,
        )!;
        expect(s.paragraphs, [
          e['para1'],
          e['para2'],
          e['para3'],
          e['para4'],
          e['para5'],
        ]);
        expect(s.recommendations, e['recommendations']);
        expect(s.suitability, e['suitability']);
        expect(s.slopeRisk, e['slopeRisk']);
      });

      test('DXF export is byte-identical', () {
        expect(DxfExporter.build(model.contours, breakLines, points), c['dxf']);
      });

      test('AutoLISP export is identical (apart from timestamp)', () {
        final lisp = AutoLispExporter.build(
          model.contours,
          breakLines,
          points,
          generatedAt: DateTime.utc(2026),
        ).split('\n');
        lisp[1] = '; Generated: <DATE>';
        expect(lisp.join('\n'), c['lisp']);
      });

      test('Civil 3D script is byte-identical', () {
        expect(
          Civil3dScriptExporter.build(model.contours, breakLines, points),
          c['civil3d'],
        );
      });
    });
  }
}
