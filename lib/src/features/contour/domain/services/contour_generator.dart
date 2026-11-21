import 'dart:math' as math;

import '../../../../core/utils/js_number.dart';
import '../entities/contour.dart';
import '../entities/geometry.dart';
import '../entities/triangle.dart';

/// Extracts contour polylines from a TIN by linear interpolation along edges.
final class ContourGenerator {
  const ContourGenerator._();

  /// Tolerance (in survey units) for joining segment end points.
  static const double _joinTolerance = 0.01;

  /// Generates contours every [interval] units; every [majorEvery]-th level is
  /// flagged as major. [smoothness] > 0 applies Catmull-Rom smoothing.
  static List<Contour> generate(
    List<Triangle> triangles,
    double interval,
    int majorEvery, {
    double smoothness = 0,
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
      final segments = _levelSegments(triangles, level);
      if (segments.isEmpty) continue;
      final isMajor = _isMajor(level, interval, majorEvery);
      for (final chain in _buildChains(segments)) {
        final points = smoothness > 0 ? smooth(chain, smoothness) : chain;
        contours.add(Contour(level: level, points: points, isMajor: isMajor));
      }
    }
    return contours;
  }

  static bool _isMajor(double level, double interval, int majorEvery) {
    if (majorEvery <= 0) return false;
    return jsRound(level / interval).remainder(majorEvery).abs() == 0;
  }

  static List<List<Point2>> _levelSegments(List<Triangle> triangles, double level) {
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

  /// Joins loose segments into polylines (open or closed).
  static List<List<Point2>> _buildChains(List<List<Point2>> segments) {
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

  /// Attaches the first unused matching segment; returns whether one was found.
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

  /// Catmull-Rom smoothing for OPEN curves; end points are kept fixed.
  static List<Point2> smooth(List<Point2> points, double smoothness) {
    if (smoothness == 0 || points.length < 3) return points;

    final segments = math.max(2, (smoothness * 2).floor());
    final first = points.first, second = points[1];
    final last = points.last, beforeLast = points[points.length - 2];
    final extended = <Point2>[
      Point2(2 * first.x - second.x, 2 * first.y - second.y),
      ...points,
      Point2(2 * last.x - beforeLast.x, 2 * last.y - beforeLast.y),
    ];

    final result = <Point2>[];
    for (var i = 1; i < extended.length - 2; i++) {
      final p0 = extended[i - 1];
      final p1 = extended[i];
      final p2 = extended[i + 1];
      final p3 = extended[i + 2];
      for (var t = 0.0; t < 1; t += 1 / segments) {
        result.add(Point2(
          _catmullRom(p0.x, p1.x, p2.x, p3.x, t),
          _catmullRom(p0.y, p1.y, p2.y, p3.y, t),
        ));
      }
    }
    result.add(Point2(last.x, last.y));
    return result;
  }

  static double _catmullRom(double p0, double p1, double p2, double p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return 0.5 *
        ((2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
  }
}
