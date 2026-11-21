import 'dart:math' as math;

import '../../domain/entities/geometry.dart';
import '../../domain/entities/triangle.dart';

/// Breakline totals shown in the breakline statistics modal.
final class BreaklineTotals {
  const BreaklineTotals({
    required this.segments,
    required this.totalLength,
    required this.averageLength,
  });

  factory BreaklineTotals.of(List<BreakLine> lines) {
    var segments = 0;
    var length = 0.0;
    for (final line in lines) {
      final pts = line.points;
      if (pts.isNotEmpty) segments += pts.length - 1;
      for (var i = 0; i + 1 < pts.length; i++) {
        final dx = pts[i + 1].x - pts[i].x;
        final dy = pts[i + 1].y - pts[i].y;
        length += math.sqrt(dx * dx + dy * dy);
      }
    }
    return BreaklineTotals(
      segments: segments,
      totalLength: length,
      averageLength: lines.isEmpty ? 0 : length / lines.length,
    );
  }

  final int segments;
  final double totalLength;
  final double averageLength;
}

/// Plan-area statistics of the TIN facets.
final class TriangleAreaStats {
  const TriangleAreaStats({
    required this.total,
    required this.average,
    required this.min,
    required this.max,
  });

  /// Null when there are no triangles.
  static TriangleAreaStats? of(List<Triangle> triangles) {
    if (triangles.isEmpty) return null;
    var total = 0.0;
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (final t in triangles) {
      final a =
          ((t.p2.x - t.p1.x) * (t.p3.y - t.p1.y) -
                  (t.p3.x - t.p1.x) * (t.p2.y - t.p1.y))
              .abs() /
          2;
      total += a;
      lo = math.min(lo, a);
      hi = math.max(hi, a);
    }
    return TriangleAreaStats(
      total: total,
      average: total / triangles.length,
      min: lo,
      max: hi,
    );
  }

  final double total;
  final double average;
  final double min;
  final double max;
}

/// Contour levels covering the RL range at a given interval.
final class ContourCoverage {
  const ContourCoverage({
    required this.lowest,
    required this.highest,
    required this.span,
    required this.levels,
  });

  factory ContourCoverage.of(double minZ, double maxZ, double interval) {
    final lowest = (minZ / interval).floorToDouble() * interval;
    final highest = (maxZ / interval).ceilToDouble() * interval;
    final span = highest - lowest;
    return ContourCoverage(
      lowest: lowest,
      highest: highest,
      span: span,
      levels: (span / interval).floor() + 1,
    );
  }

  final double lowest;
  final double highest;
  final double span;
  final int levels;
}

/// JavaScript `String(number)` for whole numbers (`1.0` prints as `1`).
String jsNumber(num v) {
  if (v is int) return '$v';
  if (v.isFinite && v == v.roundToDouble() && v.abs() < 1e21) {
    return v.toInt().toString();
  }
  return '$v';
}
