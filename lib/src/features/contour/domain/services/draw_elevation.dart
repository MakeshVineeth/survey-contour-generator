import 'dart:math' as math;

import '../../../../core/utils/js_number.dart';
import '../entities/geometry.dart';
import '../entities/triangle.dart';

/// Elevation (RL) given to a breakline point drawn on the map: interpolated
/// inside the TIN, otherwise extrapolated from the nearest survey point along
/// the mean terrain gradient (same behaviour as the original canvas click).
final class DrawElevation {
  const DrawElevation._();

  /// Barycentric slack that lets clicks just outside a triangle still count.
  static const double _edgeTolerance = 0.01;

  static double estimate({
    required double x,
    required double y,
    required List<SurveyPoint> points,
    required List<Triangle> triangles,
  }) {
    if (points.isEmpty) return 0;
    return interpolate(x, y, triangles) ?? _extrapolate(x, y, points);
  }

  /// Z from the first triangle containing (x, y), or null when outside.
  static double? interpolate(double x, double y, List<Triangle> triangles) {
    for (final tri in triangles) {
      final z = _interpolateIn(tri, x, y);
      if (z != null) return z;
    }
    return null;
  }

  static double? _interpolateIn(Triangle t, double x, double y) {
    final v0x = t.p3.x - t.p1.x, v0y = t.p3.y - t.p1.y;
    final v1x = t.p2.x - t.p1.x, v1y = t.p2.y - t.p1.y;
    final v2x = x - t.p1.x, v2y = y - t.p1.y;

    final dot00 = v0x * v0x + v0y * v0y;
    final dot01 = v0x * v1x + v0y * v1y;
    final dot02 = v0x * v2x + v0y * v2y;
    final dot11 = v1x * v1x + v1y * v1y;
    final dot12 = v1x * v2x + v1y * v2y;

    final invDenom = 1 / (dot00 * dot11 - dot01 * dot01);
    final u = (dot11 * dot02 - dot01 * dot12) * invDenom;
    final v = (dot00 * dot12 - dot01 * dot02) * invDenom;

    final inside =
        u >= -_edgeTolerance &&
        v >= -_edgeTolerance &&
        (u + v) <= 1 + _edgeTolerance;
    if (!inside) return null;
    final w = 1 - u - v;
    return w * t.p1.z + v * t.p2.z + u * t.p3.z;
  }

  static double _extrapolate(double x, double y, List<SurveyPoint> points) {
    var nearest = points.first;
    var minDist = double.infinity;
    for (final p in points) {
      final d = hypot2(p.x - x, p.y - y);
      if (d < minDist) {
        minDist = d;
        nearest = p;
      }
    }

    final (gradX, gradY) = _meanGradient(points);
    final slope = hypot2(gradX, gradY);
    var dzExpected = 0.0;
    if (slope > 0.0001 && minDist > 0.1) {
      final alignment =
          (x - nearest.x) * (gradX / slope) + (y - nearest.y) * (gradY / slope);
      dzExpected = alignment * slope;
    }
    return _clampToSurvey(nearest.z + dzExpected, points);
  }

  /// Mean of the pairwise elevation gradients (pairs closer than 0.1 skipped).
  static (double, double) _meanGradient(List<SurveyPoint> points) {
    var sumX = 0.0, sumY = 0.0;
    var count = 0;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final dx = points[j].x - points[i].x;
        final dy = points[j].y - points[i].y;
        final dist = hypot2(dx, dy);
        if (dist <= 0.1) continue;
        final mag = (points[j].z - points[i].z) / dist;
        sumX += (dx / dist) * mag;
        sumY += (dy / dist) * mag;
        count++;
      }
    }
    return count > 0 ? (sumX / count, sumY / count) : (0.0, 0.0);
  }

  static double _clampToSurvey(double z, List<SurveyPoint> points) {
    var minZ = double.infinity, maxZ = double.negativeInfinity;
    for (final p in points) {
      minZ = math.min(minZ, p.z);
      maxZ = math.max(maxZ, p.z);
    }
    var margin = (maxZ - minZ) * 0.2;
    if (margin == 0 || margin.isNaN) margin = 1;
    return math.max(minZ - margin, math.min(maxZ + margin, z));
  }
}
