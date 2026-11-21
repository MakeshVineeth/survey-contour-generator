import '../entities/contour.dart';
import '../entities/geometry.dart';
import '../entities/terrain.dart';
import '../entities/triangle.dart';
import 'contour_generator.dart';
import 'delaunay.dart';
import 'terrain_analyzer.dart';

/// Everything derived from the survey input: TIN, contours and statistics.
final class ContourModel {
  const ContourModel({
    required this.allPoints,
    required this.triangles,
    required this.contours,
    required this.stats,
  });

  static const ContourModel empty = ContourModel(
    allPoints: [],
    triangles: [],
    contours: [],
    stats: null,
  );

  /// Survey points plus breakline vertices that were merged into the TIN.
  final List<SurveyPoint> allPoints;
  final List<Triangle> triangles;
  final List<Contour> contours;
  final TerrainStats? stats;
}

/// Runs the full pipeline: merge breakline vertices, triangulate, contour and
/// analyze. Pure and synchronous; callers may run it in an isolate.
final class ContourModelBuilder {
  const ContourModelBuilder._();

  /// Breakline vertices closer than this (per axis) to an existing point are
  /// treated as duplicates and not added again.
  static const double _duplicateTolerance = 0.001;

  static ContourModel build({
    required List<SurveyPoint> points,
    required List<BreakLine> breakLines,
    required double interval,
    required int majorEvery,
    required double smoothness,
  }) {
    if (points.length < 3) return ContourModel.empty;

    final allPoints = mergeBreakLinePoints(points, breakLines);
    final triangles = Delaunay.triangulate(allPoints);
    return ContourModel(
      allPoints: allPoints,
      triangles: triangles,
      contours: ContourGenerator.generate(
        triangles,
        interval,
        majorEvery,
        smoothness: smoothness,
      ),
      stats: TerrainAnalyzer.analyze(allPoints, triangles),
    );
  }

  /// Appends breakline vertices that do not coincide with an existing point.
  static List<SurveyPoint> mergeBreakLinePoints(
    List<SurveyPoint> points,
    List<BreakLine> breakLines,
  ) {
    final merged = [...points];
    for (final bl in breakLines) {
      for (final pt in bl.points) {
        final exists = merged.any(
          (p) =>
              (p.x - pt.x).abs() < _duplicateTolerance &&
              (p.y - pt.y).abs() < _duplicateTolerance,
        );
        if (!exists) {
          merged.add(SurveyPoint(borehole: bl.name, x: pt.x, y: pt.y, z: pt.z));
        }
      }
    }
    return merged;
  }
}
