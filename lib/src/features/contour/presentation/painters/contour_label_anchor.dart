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
