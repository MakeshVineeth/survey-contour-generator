import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/js_number.dart';
import '../../domain/entities/contour.dart';
import '../../domain/entities/geometry.dart';
import '../../domain/entities/triangle.dart';
import 'contour_label_anchor.dart';
import 'viz_style.dart';

/// A major-contour label anchored at a position relative to the origin.
final class ContourLabelSpec {
  ContourLabelSpec(this.position, this.text);

  final Offset position;
  final String text;
  TextPainter? _painter;

  TextPainter get painter => _painter ??= VizStyle.label(
    text,
    VizStyle.mono(10, AppColors.accentRed, weight: FontWeight.w700, height: 1),
  );

  void dispose() => _painter?.dispose();
}

/// Immutable-per-model geometry cache for [MapPainter].
///
/// Paths and positions are stored relative to ([originX], [originY]) so that
/// large survey coordinates (e.g. UTM eastings) keep full precision in the
/// float32 canvas pipeline. Text painters are created lazily and disposed
/// with [dispose].
final class MapGeometry {
  MapGeometry._({
    required this.points,
    required this.breakLines,
    required this.triangles,
    required this.contours,
    required this.originX,
    required this.originY,
    required this.tinShared,
    required this.tinHull,
    required this.minor,
    required this.major,
    required this.breakLinePolys,
    required this.pointRel,
    required this.contourLabels,
  }) : _bhLabels = List<TextPainter?>.filled(points.length, null),
       _rlLabels = List<TextPainter?>.filled(points.length, null);

  factory MapGeometry.build({
    required List<SurveyPoint> points,
    required List<BreakLine> breakLines,
    required List<Triangle> triangles,
    required List<Contour> contours,
  }) {
    final origin = _origin(points);
    final tin = _buildTin(triangles, origin);
    final contourPaths = _buildContours(contours, origin, points);
    return MapGeometry._(
      points: points,
      breakLines: breakLines,
      triangles: triangles,
      contours: contours,
      originX: origin.dx,
      originY: origin.dy,
      tinShared: tin.shared,
      tinHull: tin.hull,
      minor: contourPaths.minor,
      major: contourPaths.major,
      breakLinePolys: [
        for (final bl in breakLines)
          if (bl.points.length >= 2)
            [
              for (final p in bl.points)
                Offset(p.x - origin.dx, p.y - origin.dy),
            ],
      ],
      pointRel: [
        for (final p in points) Offset(p.x - origin.dx, p.y - origin.dy),
      ],
      contourLabels: contourPaths.labels,
    );
  }

  final List<SurveyPoint> points;
  final List<BreakLine> breakLines;
  final List<Triangle> triangles;
  final List<Contour> contours;
  final double originX;
  final double originY;

  /// TIN edges shared by two triangles (drawn twice in the reference, so
  /// they are composited at a higher alpha than hull edges).
  final Path tinShared;
  final Path tinHull;
  final Path minor;
  final Path major;
  final List<List<Offset>> breakLinePolys;
  final List<Offset> pointRel;
  final List<ContourLabelSpec> contourLabels;

  final List<TextPainter?> _bhLabels;
  final List<TextPainter?> _rlLabels;

  bool matches(
    List<SurveyPoint> p,
    List<BreakLine> b,
    List<Triangle> t,
    List<Contour> c,
  ) =>
      identical(p, points) &&
      identical(b, breakLines) &&
      identical(t, triangles) &&
      identical(c, contours);

  /// Borehole label (bold 10px mono, cyan).
  TextPainter boreholeLabel(int i) => _bhLabels[i] ??= VizStyle.label(
    points[i].borehole,
    VizStyle.mono(10, AppColors.accentCyan, weight: FontWeight.w700, height: 1),
  );

  /// Reduced-level label (9px mono, green).
  TextPainter levelLabel(int i) => _rlLabels[i] ??= VizStyle.label(
    'RL ${points[i].z.toFixed(2)}',
    VizStyle.mono(9, AppColors.accentGreen, height: 1),
  );

  void dispose() {
    for (final tp in _bhLabels) {
      tp?.dispose();
    }
    for (final tp in _rlLabels) {
      tp?.dispose();
    }
    for (final l in contourLabels) {
      l.dispose();
    }
  }

  static Offset _origin(List<SurveyPoint> points) {
    if (points.isEmpty) return Offset.zero;
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final p in points) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  static ({Path shared, Path hull}) _buildTin(
    List<Triangle> triangles,
    Offset origin,
  ) {
    final index = Map<SurveyPoint, int>.identity();
    int idOf(SurveyPoint p) => index.putIfAbsent(p, () => index.length);
    final counts = <int, int>{};
    final edges = <(int, int, SurveyPoint, SurveyPoint)>[];
    for (final t in triangles) {
      final ids = [idOf(t.p1), idOf(t.p2), idOf(t.p3)];
      final pts = [t.p1, t.p2, t.p3];
      for (var k = 0; k < 3; k++) {
        final a = ids[k];
        final b = ids[(k + 1) % 3];
        final key = a < b ? a * 0x100000000 + b : b * 0x100000000 + a;
        counts[key] = (counts[key] ?? 0) + 1;
        edges.add((a, b, pts[k], pts[(k + 1) % 3]));
      }
    }
    final shared = Path();
    final hull = Path();
    final seen = <int>{};
    for (final e in edges) {
      final key = e.$1 < e.$2
          ? e.$1 * 0x100000000 + e.$2
          : e.$2 * 0x100000000 + e.$1;
      if (!seen.add(key)) continue;
      final target = (counts[key] ?? 1) > 1 ? shared : hull;
      target
        ..moveTo(e.$3.x - origin.dx, e.$3.y - origin.dy)
        ..lineTo(e.$4.x - origin.dx, e.$4.y - origin.dy);
    }
    return (shared: shared, hull: hull);
  }

  static ({Path minor, Path major, List<ContourLabelSpec> labels})
  _buildContours(
    List<Contour> contours,
    Offset origin,
    List<SurveyPoint> survey,
  ) {
    final clearance = ContourLabelAnchor.clearanceFor(survey);
    final minor = Path();
    final major = Path();
    final labels = <ContourLabelSpec>[];
    for (final c in contours) {
      if (c.points.isEmpty) continue;
      final path = c.isMajor ? major : minor;
      path.moveTo(c.points[0].x - origin.dx, c.points[0].y - origin.dy);
      for (var i = 1; i < c.points.length; i++) {
        path.lineTo(c.points[i].x - origin.dx, c.points[i].y - origin.dy);
      }
      if (c.isMajor && c.points.length >= 2) {
        final mid = c.points[ContourLabelAnchor.indexFor(
          c.points,
          survey,
          clearance,
        )];
        labels.add(
          ContourLabelSpec(
            Offset(mid.x - origin.dx, mid.y - origin.dy),
            c.level.toFixed(1),
          ),
        );
      }
    }
    return (minor: minor, major: major, labels: labels);
  }
}
