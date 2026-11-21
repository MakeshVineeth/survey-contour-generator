import 'dart:math' as math;

import '../entities/geometry.dart';
import '../entities/triangle.dart';

/// Bowyer-Watson Delaunay triangulation.
///
/// Faithful port of the original implementation: same super-triangle, same
/// circumcircle tolerance and same iteration order, so the produced triangles
/// (and their order) match the web application.
final class Delaunay {
  const Delaunay._();

  static List<Triangle> triangulate(List<SurveyPoint> points) {
    final n = points.length;
    if (n < 3) return const [];

    // Vertex coordinates; indices n..n+2 are the super-triangle corners.
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

    var triangles = <_Tri>[_Tri(n, n + 1, n + 2)];

    for (var p = 0; p < n; p++) {
      final bad = <_Tri>[
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

      final badSet = Set<_Tri>.identity()..addAll(bad);
      triangles = [
        for (final t in triangles)
          if (!badSet.contains(t)) t,
      ];
      for (final edge in polygon) {
        triangles.add(_Tri(edge.$1, edge.$2, p));
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
    _Tri tri,
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

/// Triangle over vertex indices (identity-compared, like the JS objects).
final class _Tri {
  _Tri(this.a, this.b, this.c);

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
