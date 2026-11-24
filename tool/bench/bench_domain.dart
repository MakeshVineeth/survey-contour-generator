// ignore_for_file: avoid_print, prefer_final_locals
// Run: dart run tool/bench/bench_domain.dart [sizes...]
import 'dart:io';

import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/autolisp_exporter.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/civil3d_script_exporter.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_generator.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_model_builder.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/delaunay.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/dxf_exporter.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/terrain_analyzer.dart';

import 'bench_data.dart';

int rss() => ProcessInfo.currentRss;

void time(String label, void Function() body) {
  final before = rss();
  final sw = Stopwatch()..start();
  body();
  sw.stop();
  stdout.writeln('  ${label.padRight(22)} ${sw.elapsedMilliseconds.toString().padLeft(8)} ms'
      '   rssDelta ${((rss() - before) / 1048576).toStringAsFixed(1)} MB');
}

void main(List<String> args) {
  final sizes = args.isEmpty ? [100, 1000, 5000, 20000] : args.map(int.parse).toList();
  for (final n in sizes) {
    stdout.writeln('== n=$n');
    final pts = generateSurvey(n);
    late final ContourModel model;
    time('model build (0.5 int)', () {
      model = ContourModelBuilder.build(
          points: pts, breakLines: const [], interval: 0.5, majorEvery: 5, smoothness: 0);
    });
    stdout.writeln('  tris=${model.triangles.length} contours=${model.contours.length}');
    time('delaunay', () => Delaunay.triangulate(pts));
    time('contours', () => ContourGenerator.generate(model.triangles, 0.5, 5));
    time('contours smooth=3', () => ContourGenerator.generate(model.triangles, 0.5, 5, smoothness: 3));
    time('analyze', () => TerrainAnalyzer.analyze(pts, model.triangles));
    final bl = [
      BreakLine(name: 'L1', points: [for (var i = 0; i < 50; i++) Point3(500000.0 + i * 3.3, 4000000.0 + i * 2.1, 100.0 + i)])
    ];
    time('merge breaklines', () => ContourModelBuilder.mergeBreakLinePoints(pts, bl));
    var len = 0;
    time('dxf', () => len = DxfExporter.build(model.contours, bl, pts).length);
    stdout.writeln('    dxf chars=$len');
    time('autolisp', () => len = AutoLispExporter.build(model.contours, bl, pts, generatedAt: DateTime.utc(2026)).length);
    time('civil3d', () => len = Civil3dScriptExporter.build(model.contours, bl, pts).length);
  }
}
