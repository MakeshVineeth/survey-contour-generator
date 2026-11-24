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
      minZ = math.min(minZ, t.p1.z);
      maxZ = math.max(maxZ, t.p1.z);
      minZ = math.min(minZ, t.p2.z);
      maxZ = math.max(maxZ, t.p2.z);
      minZ = math.min(minZ, t.p3.z);
      maxZ = math.max(maxZ, t.p3.z);
    }
    final startLevel = (minZ / interval).ceilToDouble() * interval;
    final endLevel = (maxZ / interval).floorToDouble() * interval;

    final contours = <Contour>[];
    for (var level = startLevel; level <= endLevel; level += interval) {
      final segments = _levelSegments(triangles, level);
      if (segments.length == 0) continue;
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

  /// Segments of one level as parallel start/end lists (edge order of the
  /// first two crossings of each triangle).
  static _Segments _levelSegments(List<Triangle> triangles, double level) {
    final starts = <Point2>[];
    final ends = <Point2>[];
    for (final tri in triangles) {
      final a = tri.p1, b = tri.p2, c = tri.p3;
      Point2? first, second;
      var count = 0;
      for (var i = 0; i < 3; i++) {
        final p1 = i == 0 ? a : (i == 1 ? b : c);
        final p2 = i == 0 ? b : (i == 1 ? c : a);
        final crosses = (p1.z < level && p2.z >= level) ||
            (p2.z < level && p1.z >= level);
        if (!crosses) continue;
        final t = (level - p1.z) / (p2.z - p1.z);
        final crossing =
            Point2(p1.x + t * (p2.x - p1.x), p1.y + t * (p2.y - p1.y));
        if (count == 0) {
          first = crossing;
        } else if (count == 1) {
          second = crossing;
        }
        count++;
      }
      if (count == 2) {
        starts.add(first!);
        ends.add(second!);
      }
    }
    return _Segments(starts, ends);
  }

  /// Joins loose segments into polylines (open or closed).
  ///
  /// Behaves exactly like scanning all unused segments in index order for the
  /// first one whose end point is within [_joinTolerance] of the chain's last
  /// or first point; the scan is replaced by a spatial hash lookup that yields
  /// the smallest matching index.
  static List<List<Point2>> _buildChains(_Segments segments) {
    final chains = <List<Point2>>[];
    final count = segments.length;
    final used = List<bool>.filled(count, false);
    final grid = _EndpointGrid(segments);

    for (var i = 0; i < count; i++) {
      if (used[i]) continue;
      used[i] = true;
      // `front` holds the points inserted before the chain start, reversed.
      final front = <Point2>[];
      final back = <Point2>[segments.starts[i], segments.ends[i]];

      while (true) {
        final last = back.last;
        final first = front.isEmpty ? back.first : front.last;
        final j = grid.firstMatch(first, last, used);
        if (j < 0) break;
        used[j] = true;
        final s = segments.starts[j], e = segments.ends[j];
        if (_near(last, s)) {
          back.add(e);
        } else if (_near(last, e)) {
          back.add(s);
        } else if (_near(first, s)) {
          front.add(e);
        } else {
          front.add(s);
        }
      }
      chains.add([...front.reversed, ...back]);
    }
    return chains;
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

/// Level segments as parallel start/end point lists.
final class _Segments {
  _Segments(this.starts, this.ends);

  final List<Point2> starts;
  final List<Point2> ends;

  int get length => starts.length;
}

/// Spatial hash over segment end points.
///
/// Cells are twice the join tolerance wide, so two points closer than the
/// tolerance always fall into the same or adjacent cells (3x3 neighbourhood).
/// Candidates are re-checked with the exact distance test, so a hash collision
/// or an over-wide neighbourhood can only add work, never change the result.
final class _EndpointGrid {
  _EndpointGrid(this._segments) {
    for (var j = 0; j < _segments.length; j++) {
      _insert(_segments.starts[j], j);
      _insert(_segments.ends[j], j);
    }
  }

  static const double _cellSize = 2 * ContourGenerator._joinTolerance;

  /// Beyond this many cells from the origin coordinates are "far" and kept in
  /// one shared list (avoids int overflow / precision issues).
  static const double _farCells = 1e15;

  final _Segments _segments;
  final Map<int, List<int>> _cells = {};
  final List<int> _far = [];

  /// Cell index of [v], or null when it is too large to hash safely.
  static int? _cell(double v) {
    final q = v / _cellSize;
    return q.abs() > _farCells ? null : q.floor();
  }

  static int _key(int cx, int cy) => cx * 1000003 + cy;

  void _insert(Point2 p, int segment) {
    if (!p.x.isFinite || !p.y.isFinite) return; // never "near" anything
    final cx = _cell(p.x), cy = _cell(p.y);
    if (cx == null || cy == null) {
      if (_far.isEmpty || _far.last != segment) _far.add(segment);
      return;
    }
    final list = _cells.putIfAbsent(_key(cx, cy), () => <int>[]);
    if (list.isEmpty || list.last != segment) list.add(segment);
  }

  /// Smallest unused segment index with an end point near [first] or [last],
  /// or -1.
  int firstMatch(Point2 first, Point2 last, List<bool> used) {
    var best = _segments.length;
    best = _scan(last, used, best);
    if (!identical(first, last)) best = _scan(first, used, best);
    return best == _segments.length ? -1 : best;
  }

  int _scan(Point2 q, List<bool> used, int best) {
    if (!q.x.isFinite || !q.y.isFinite) return best;
    best = _scanList(_far, q, used, best);
    final cx = _cell(q.x), cy = _cell(q.y);
    if (cx == null || cy == null) return best;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final list = _cells[_key(cx + dx, cy + dy)];
        if (list != null) best = _scanList(list, q, used, best);
      }
    }
    return best;
  }

  /// [list] is in ascending segment order, so the scan stops at [best].
  int _scanList(List<int> list, Point2 q, List<bool> used, int best) {
    for (final j in list) {
      if (j >= best) break;
      if (used[j]) continue;
      if (ContourGenerator._near(q, _segments.starts[j]) ||
          ContourGenerator._near(q, _segments.ends[j])) {
        return j;
      }
    }
    return best;
  }
}
