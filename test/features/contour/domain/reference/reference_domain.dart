// Straightforward reference implementations (verbatim copies of the original,
// un-optimised algorithms) used to prove that the optimised domain code
// produces identical output. Do NOT "improve" this file.
import 'dart:math' as math;

import 'package:survey_contour_generator/src/core/utils/js_number.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/contour.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/triangle.dart';

/// Original Bowyer-Watson implementation.
final class ReferenceDelaunay {
  const ReferenceDelaunay._();

  static List<Triangle> triangulate(List<SurveyPoint> points) {
    final n = points.length;
    if (n < 3) return const [];

    final xs = List<double>.filled(n + 3, 0);
    final ys = List<double>.filled(n + 3, 0);
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      xs[i] = points[i].x;
      ys[i] = points[i].y;
      minX = math.min(minX, xs[i]);
      maxX = math.max(maxX, xs[i]);
      minY = math.min(minY, ys[i]);
      maxY = math.max(maxY, ys[i]);
    }

    final dmax = math.max(maxX - minX, maxY - minY) * 3;
    final midX = (minX + maxX) / 2;
    final midY = (minY + maxY) / 2;
    xs[n] = midX - dmax * 2;
    ys[n] = midY - dmax;
    xs[n + 1] = midX + dmax * 2;
    ys[n + 1] = midY - dmax;
    xs[n + 2] = midX;
    ys[n + 2] = midY + dmax * 2;

    var triangles = <_RefTri>[_RefTri(n, n + 1, n + 2)];

    for (var p = 0; p < n; p++) {
      final bad = <_RefTri>[
        for (final t in triangles)
          if (_inCircumcircle(xs[p], ys[p], t, xs, ys)) t,
      ];

      final polygon = <(int, int)>[];
      for (final tri in bad) {
        for (final edge in tri.edges) {
          final shared = bad.any(
            (other) => !identical(other, tri) && other.hasEdge(edge.$1, edge.$2),
          );
          if (!shared) polygon.add(edge);
        }
      }

      final badSet = Set<_RefTri>.identity()..addAll(bad);
      triangles = [
        for (final t in triangles)
          if (!badSet.contains(t)) t,
      ];
      for (final edge in polygon) {
        triangles.add(_RefTri(edge.$1, edge.$2, p));
      }
    }

    return [
      for (final t in triangles)
        if (t.a < n && t.b < n && t.c < n)
          Triangle(points[t.a], points[t.b], points[t.c]),
    ];
  }

  static bool _inCircumcircle(
    double px,
    double py,
    _RefTri tri,
    List<double> xs,
    List<double> ys,
  ) {
    final ax = xs[tri.a] - px, ay = ys[tri.a] - py;
    final bx = xs[tri.b] - px, by = ys[tri.b] - py;
    final cx = xs[tri.c] - px, cy = ys[tri.c] - py;
    final det = (ax * ax + ay * ay) * (bx * cy - cx * by) -
        (bx * bx + by * by) * (ax * cy - cx * ay) +
        (cx * cx + cy * cy) * (ax * by - bx * ay);
    return det > 1e-10;
  }
}

final class _RefTri {
  _RefTri(this.a, this.b, this.c);

  final int a;
  final int b;
  final int c;

  List<(int, int)> get edges => [(a, b), (b, c), (c, a)];

  bool hasEdge(int u, int v) =>
      (a == u && b == v) ||
      (b == u && a == v) ||
      (b == u && c == v) ||
      (c == u && b == v) ||
      (c == u && a == v) ||
      (a == u && c == v);
}

/// Original contour chain builder (O(segments^2) per level).
final class ReferenceContourGenerator {
  const ReferenceContourGenerator._();

  static const double _joinTolerance = 0.01;

  static List<Contour> generate(
    List<Triangle> triangles,
    double interval,
    int majorEvery, {
    double smoothness = 0,
    List<Point2> Function(List<Point2>, double)? smooth,
  }) {
    if (!(interval > 0) || interval.isInfinite) {
      throw ArgumentError.value(interval, 'interval', 'must be a positive number');
    }
    if (triangles.isEmpty) return const [];

    var minZ = double.infinity, maxZ = double.negativeInfinity;
    for (final t in triangles) {
      for (final z in [t.p1.z, t.p2.z, t.p3.z]) {
        minZ = math.min(minZ, z);
        maxZ = math.max(maxZ, z);
      }
    }
    final startLevel = (minZ / interval).ceilToDouble() * interval;
    final endLevel = (maxZ / interval).floorToDouble() * interval;

    final contours = <Contour>[];
    for (var level = startLevel; level <= endLevel; level += interval) {
      final segments = levelSegments(triangles, level);
      if (segments.isEmpty) continue;
      final isMajor = _isMajor(level, interval, majorEvery);
      for (final chain in buildChains(segments)) {
        final points =
            smoothness > 0 && smooth != null ? smooth(chain, smoothness) : chain;
        contours.add(Contour(level: level, points: points, isMajor: isMajor));
      }
    }
    return contours;
  }

  static bool _isMajor(double level, double interval, int majorEvery) {
    if (majorEvery <= 0) return false;
    return jsRound(level / interval).remainder(majorEvery).abs() == 0;
  }

  static List<List<Point2>> levelSegments(List<Triangle> triangles, double level) {
    final segments = <List<Point2>>[];
    for (final tri in triangles) {
      final pts = [tri.p1, tri.p2, tri.p3];
      final crossings = <Point2>[];
      for (var i = 0; i < 3; i++) {
        final p1 = pts[i], p2 = pts[(i + 1) % 3];
        final crosses = (p1.z < level && p2.z >= level) ||
            (p2.z < level && p1.z >= level);
        if (crosses) {
          final t = (level - p1.z) / (p2.z - p1.z);
          crossings.add(Point2(p1.x + t * (p2.x - p1.x), p1.y + t * (p2.y - p1.y)));
        }
      }
      if (crossings.length == 2) segments.add(crossings);
    }
    return segments;
  }

  static List<List<Point2>> buildChains(List<List<Point2>> segments) {
    final chains = <List<Point2>>[];
    final used = List<bool>.filled(segments.length, false);

    for (var i = 0; i < segments.length; i++) {
      if (used[i]) continue;
      final chain = [...segments[i]];
      used[i] = true;

      var extended = true;
      while (extended) {
        extended = _extendChain(chain, segments, used);
      }
      if (chain.length >= 2) chains.add(chain);
    }
    return chains;
  }

  static bool _extendChain(
    List<Point2> chain,
    List<List<Point2>> segments,
    List<bool> used,
  ) {
    final last = chain.last;
    final first = chain.first;
    for (var j = 0; j < segments.length; j++) {
      if (used[j]) continue;
      final seg = segments[j];
      if (_near(last, seg[0])) {
        chain.add(seg[1]);
      } else if (_near(last, seg[1])) {
        chain.add(seg[0]);
      } else if (_near(first, seg[0])) {
        chain.insert(0, seg[1]);
      } else if (_near(first, seg[1])) {
        chain.insert(0, seg[0]);
      } else {
        continue;
      }
      used[j] = true;
      return true;
    }
    return false;
  }

  static bool _near(Point2 a, Point2 b) =>
      hypot2(a.x - b.x, a.y - b.y) < _joinTolerance;
}
