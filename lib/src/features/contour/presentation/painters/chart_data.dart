import 'dart:math' as math;

import '../../domain/entities/geometry.dart';
import '../../domain/entities/triangle.dart';

/// One survey point in the sorted elevation profile.
final class ElevationSample {
  const ElevationSample(this.name, this.z);

  final String name;
  final double z;
}

/// Survey points sorted by elevation (stable, like `Array.sort`).
List<ElevationSample> sortedElevations(List<SurveyPoint> points) {
  final indexed = [for (var i = 0; i < points.length; i++) (i, points[i])]
    ..sort((a, b) {
      final c = a.$2.z.compareTo(b.$2.z);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) ElevationSample(e.$2.borehole, e.$2.z)];
}

/// Min/max RL of the survey points (0/0 without points, as in the reference).
({double min, double max}) elevationExtent(List<SurveyPoint> points) {
  if (points.isEmpty) return (min: 0, max: 0);
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (final p in points) {
    lo = math.min(lo, p.z);
    hi = math.max(hi, p.z);
  }
  return (min: lo, max: hi);
}

/// Display data of one slope class.
final class SlopeBin {
  const SlopeBin({
    required this.name,
    required this.count,
    required this.color,
    required this.gradientEnd,
    required this.description,
  });

  final String name;
  final int count;

  /// ARGB colour of the slice (Highcharts small chart).
  final int color;

  /// Darker gradient end used by the expanded chart.
  final int gradientEnd;
  final String description;
}

/// Slope classification of the triangles (reference lines 3034–3053 and
/// 3152–3175: the larger of the two edge slopes from vertex 1).
final class SlopeAnalysis {
  const SlopeAnalysis({
    required this.bins,
    required this.total,
    required this.avg,
    required this.min,
    required this.max,
  });

  factory SlopeAnalysis.fromTriangles(List<Triangle> triangles) {
    final counts = List<int>.filled(5, 0);
    var sum = 0.0;
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (final t in triangles) {
      final s = _triangleSlope(t);
      counts[_classOf(s)]++;
      sum += s;
      lo = math.min(lo, s);
      hi = math.max(hi, s);
    }
    final total = triangles.length;
    return SlopeAnalysis(
      bins: [
        for (var i = 0; i < 5; i++)
          SlopeBin(
            name: _names[i],
            count: counts[i],
            color: _colors[i],
            gradientEnd: _gradientEnds[i],
            description: _descriptions[i],
          ),
      ],
      total: total,
      avg: total == 0 ? 0 : sum / total,
      min: total == 0 ? 0 : lo,
      max: total == 0 ? 0 : hi,
    );
  }

  final List<SlopeBin> bins;
  final int total;
  final double avg;
  final double min;
  final double max;

  /// Bins with at least one triangle (the charts filter `y > 0`).
  List<SlopeBin> get nonEmpty => [
    for (final b in bins)
      if (b.count > 0) b,
  ];

  static const List<String> _names = [
    'Flat (0-5°)',
    'Gentle (5-15°)',
    'Moderate (15-30°)',
    'Steep (30-45°)',
    'Extreme (>45°)',
  ];
  static const List<int> _colors = [
    0xFF00FF88,
    0xFF00D9FF,
    0xFFFFD93D,
    0xFFFF6B35,
    0xFFFF4757,
  ];
  static const List<int> _gradientEnds = [
    0xFF00CC6A,
    0xFF0099CC,
    0xFFE6B800,
    0xFFCC4400,
    0xFFCC2233,
  ];
  static const List<String> _descriptions = [
    'Nearly level terrain, ideal for construction',
    'Slight incline, good drainage',
    'Noticeable slope, may need grading',
    'Significant grade, erosion risk',
    'Very steep, stability concerns',
  ];

  static int _classOf(double s) {
    if (s < 5) return 0;
    if (s < 15) return 1;
    if (s < 30) return 2;
    if (s < 45) return 3;
    return 4;
  }

  static double _triangleSlope(Triangle t) {
    final a = _edgeSlope(t.p1, t.p2);
    final b = _edgeSlope(t.p1, t.p3);
    return math.max(a, b);
  }

  static double _edgeSlope(SurveyPoint a, SurveyPoint b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= 0) return 0;
    return math.atan((b.z - a.z).abs() / dist) * 180 / math.pi;
  }
}
