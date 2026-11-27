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
    if (breakLines.every((bl) => bl.points.isEmpty)) return merged;
    // Same "any point within the tolerance on both axes" test as a linear
    // scan over `merged`, with the scan narrowed to nearby grid cells.
    final grid = _DuplicateGrid(merged);
    for (final bl in breakLines) {
      for (final pt in bl.points) {
        if (grid.hasNear(pt.x, pt.y)) continue;
        final added = SurveyPoint(borehole: bl.name, x: pt.x, y: pt.y, z: pt.z);
        merged.add(added);
        grid.add(added);
      }
    }
    return merged;
  }
}

/// Spatial hash answering "is any point within `tol` on both axes of (x, y)".
///
/// Cells are twice the tolerance wide, so a point closer than the tolerance on
/// both axes is in the same or an adjacent cell; candidates are re-checked
/// with the exact comparison. Points with non-finite or absurdly large
/// coordinates are kept in a separate list that is always scanned.
final class _DuplicateGrid {
  _DuplicateGrid(List<SurveyPoint> initial) {
    for (final p in initial) {
      add(p);
    }
  }

  static const double _tol = ContourModelBuilder._duplicateTolerance;
  static const double _cell = 2 * _tol;
  static const double _farCells = 1e15;

  final Map<int, List<SurveyPoint>> _cells = {};
  final List<SurveyPoint> _far = [];

  static int? _index(double v) {
    final q = v / _cell;
    return q.abs() > _farCells ? null : q.floor();
  }

  static int _key(int cx, int cy) => cx * 1000003 + cy;

  static bool _close(SurveyPoint p, double x, double y) =>
      (p.x - x).abs() < _tol && (p.y - y).abs() < _tol;

  void add(SurveyPoint p) {
    // NaN never compares close to anything, so it never needs to be found.
    if (p.x.isNaN || p.y.isNaN) return;
    final cx = p.x.isFinite ? _index(p.x) : null;
    final cy = p.y.isFinite ? _index(p.y) : null;
    if (cx == null || cy == null) {
      _far.add(p);
    } else {
      (_cells[_key(cx, cy)] ??= <SurveyPoint>[]).add(p);
    }
  }

  bool hasNear(double x, double y) {
    if (x.isNaN || y.isNaN) return false;
    for (final p in _far) {
      if (_close(p, x, y)) return true;
    }
    final cx = x.isFinite ? _index(x) : null;
    final cy = y.isFinite ? _index(y) : null;
    if (cx == null || cy == null) {
      // Too large (or infinite) to hash: nothing finite and nearby is stored
      // in a cell unless the exact test says so, so check the cells' points.
      for (final bucket in _cells.values) {
        for (final p in bucket) {
          if (_close(p, x, y)) return true;
        }
      }
      return false;
    }
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final bucket = _cells[_key(cx + dx, cy + dy)];
        if (bucket == null) continue;
        for (final p in bucket) {
          if (_close(p, x, y)) return true;
        }
      }
    }
    return false;
  }
}
