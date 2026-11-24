import 'dart:math' as math;

import '../../domain/entities/geometry.dart';

/// Chooses where on a contour its elevation label is anchored.
///
/// The reference anchors every label at the middle vertex, which can land
/// right on top of a survey point and its text. This keeps the middle vertex
/// whenever it is clear of every survey point, and otherwise slides along the
/// contour to the nearest vertex that is.
final class ContourLabelAnchor {
  const ContourLabelAnchor._();

  /// Clearance as a fraction of the survey's diagonal.
  static const double _clearanceFraction = 0.045;

  /// Distance (in survey units) a label must keep from survey points.
  static double clearanceFor(List<SurveyPoint> survey) {
    if (survey.isEmpty) return 0;
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in survey) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final diagonal = math.sqrt(
      math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2),
    );
    return diagonal.isFinite ? diagonal * _clearanceFraction : 0;
  }

  /// Index into [pts] (length >= 2) at which to anchor the label.
  static int indexFor(
    List<Point2> pts,
    List<SurveyPoint> survey,
    double clearance,
  ) {
    final mid = pts.length ~/ 2;
    if (clearance <= 0 || survey.isEmpty) return mid;
    if (_isClear(pts[mid], survey, clearance)) return mid;

    // Nearest-to-middle first, so the label stays as central as possible.
    final limit = math.max(mid, pts.length - 1 - mid);
    for (var step = 1; step <= limit; step++) {
      for (final i in [mid - step, mid + step]) {
        if (i < 0 || i >= pts.length) continue;
        if (_isClear(pts[i], survey, clearance)) return i;
      }
    }
    return mid;
  }

  static bool _isClear(
    Point2 p,
    List<SurveyPoint> survey,
    double clearance,
  ) {
    final c2 = clearance * clearance;
    for (final s in survey) {
      final dx = s.x - p.x;
      final dy = s.y - p.y;
      if (dx * dx + dy * dy < c2) return false;
    }
    return true;
  }
}

/// [ContourLabelAnchor] with the survey indexed in a uniform grid.
///
/// Gives exactly the same answers as the static functions: the grid only
/// narrows which survey points the very same `dx*dx + dy*dy < clearance^2`
/// test is evaluated for. Cells are 1 % wider than the clearance, so every
/// point closer than the clearance lies in the 3x3 cells around the query.
/// Building it once turns the per-contour O(survey) scan (which made
/// `MapGeometry.build` take seconds at 20 000 points) into O(1) lookups.
final class IndexedLabelAnchor {
  factory IndexedLabelAnchor(List<SurveyPoint> survey) {
    final clearance = ContourLabelAnchor.clearanceFor(survey);
    return IndexedLabelAnchor._(survey, clearance);
  }

  IndexedLabelAnchor._(this._survey, this.clearance) {
    if (clearance > 0 && _survey.isNotEmpty) _buildGrid();
  }

  /// Distance a label must keep from survey points (`clearanceFor`).
  final double clearance;

  final List<SurveyPoint> _survey;
  double _minX = 0;
  double _minY = 0;
  double _cell = 1;
  int _w = 0;
  int _h = 0;
  List<List<SurveyPoint>?>? _cells;

  void _buildGrid() {
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in _survey) {
      if (!p.x.isFinite || !p.y.isFinite) continue; // never within reach
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    if (!minX.isFinite) return;
    final cell = clearance * 1.01;
    final w = ((maxX - minX) / cell).floor() + 1;
    final h = ((maxY - minY) / cell).floor() + 1;
    if (!cell.isFinite || w * h > 1000000) return; // fall back to the scan
    _minX = minX;
    _minY = minY;
    _cell = cell;
    _w = w;
    _h = h;
    final cells = List<List<SurveyPoint>?>.filled(w * h, null);
    for (final p in _survey) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      final cx = ((p.x - minX) / cell).floor();
      final cy = ((p.y - minY) / cell).floor();
      (cells[cy * w + cx] ??= <SurveyPoint>[]).add(p);
    }
    _cells = cells;
  }

  /// Same result as [ContourLabelAnchor.indexFor] for this survey.
  int indexFor(List<Point2> pts) {
    final mid = pts.length ~/ 2;
    if (clearance <= 0 || _survey.isEmpty) return mid;
    if (_isClear(pts[mid])) return mid;
    final limit = math.max(mid, pts.length - 1 - mid);
    for (var step = 1; step <= limit; step++) {
      final lo = mid - step, hi = mid + step;
      if (lo >= 0 && _isClear(pts[lo])) return lo;
      if (hi < pts.length && _isClear(pts[hi])) return hi;
    }
    return mid;
  }

  bool _isClear(Point2 p) {
    final cells = _cells;
    if (cells == null) return _scanIsClear(p, _survey);
    // Non-finite (or absurdly distant) points are clear of every survey point.
    if (!p.x.isFinite || !p.y.isFinite) return true;
    final qx = (p.x - _minX) / _cell, qy = (p.y - _minY) / _cell;
    if (!(qx.abs() < 1e12 && qy.abs() < 1e12)) return true;
    final cx = qx.floor(), cy = qy.floor();
    final c2 = clearance * clearance;
    for (var gy = math.max(cy - 1, 0); gy <= math.min(cy + 1, _h - 1); gy++) {
      for (var gx = math.max(cx - 1, 0); gx <= math.min(cx + 1, _w - 1); gx++) {
        final bucket = cells[gy * _w + gx];
        if (bucket == null) continue;
        if (!_bucketIsClear(bucket, p, c2)) return false;
      }
    }
    return true;
  }

  bool _scanIsClear(Point2 p, List<SurveyPoint> survey) =>
      _bucketIsClear(survey, p, clearance * clearance);

  static bool _bucketIsClear(List<SurveyPoint> bucket, Point2 p, double c2) {
    for (final s in bucket) {
      final dx = s.x - p.x;
      final dy = s.y - p.y;
      if (dx * dx + dy * dy < c2) return false;
    }
    return true;
  }
}
