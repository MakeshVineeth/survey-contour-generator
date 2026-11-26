import 'dart:math' as math;
import 'dart:typed_data';

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
  final Map<String, TextPainter> _bhByText = {};
  final Map<String, TextPainter> _rlByText = {};

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
  TextPainter boreholeLabel(int i) {
    final cached = _bhLabels[i];
    if (cached != null) return cached;
    final text = points[i].borehole;
    return _bhLabels[i] = _bhByText.putIfAbsent(
      text,
      () => VizStyle.label(
        text,
        VizStyle.mono(
          10,
          AppColors.accentCyan,
          weight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }

  /// Reduced-level label (9px mono, green). Identical texts share one
  /// laid-out painter (same text and style paint identically); many points
  /// share the same rounded level.
  TextPainter levelLabel(int i) {
    final cached = _rlLabels[i];
    if (cached != null) return cached;
    final text = 'RL ${points[i].z.toFixed(2)}';
    return _rlLabels[i] = _rlByText.putIfAbsent(
      text,
      () => VizStyle.label(
        text,
        VizStyle.mono(9, AppColors.accentGreen, height: 1),
      ),
    );
  }

  void dispose() {
    // Labels may be shared between points: dispose each painter once.
    for (final tp in _bhByText.values) {
      tp.dispose();
    }
    _bhByText.clear();
    for (final tp in _rlByText.values) {
      tp.dispose();
    }
    _rlByText.clear();
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
    // Vertex ids per triangle corner (creation order of the ids matters only
    // for being unique, the path order follows the triangle order).
    final ids = Int32List(triangles.length * 3);
    final counts = <int, int>{};
    var o = 0;
    for (final t in triangles) {
      final a = idOf(t.p1), b = idOf(t.p2), c = idOf(t.p3);
      ids[o] = a;
      ids[o + 1] = b;
      ids[o + 2] = c;
      o += 3;
      _countEdge(counts, a, b);
      _countEdge(counts, b, c);
      _countEdge(counts, c, a);
    }
    final shared = Path();
    final hull = Path();
    o = 0;
    for (final t in triangles) {
      final a = ids[o], b = ids[o + 1], c = ids[o + 2];
      o += 3;
      _emitEdge(counts, a, b, t.p1, t.p2, origin, shared, hull);
      _emitEdge(counts, b, c, t.p2, t.p3, origin, shared, hull);
      _emitEdge(counts, c, a, t.p3, t.p1, origin, shared, hull);
    }
    return (shared: shared, hull: hull);
  }

  static int _edgeKey(int a, int b) =>
      a < b ? a * 0x100000000 + b : b * 0x100000000 + a;

  static void _countEdge(Map<int, int> counts, int a, int b) {
    final key = _edgeKey(a, b);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  /// Adds the undirected edge once (first occurrence wins); a negative count
  /// marks an edge that was already emitted.
  static void _emitEdge(
    Map<int, int> counts,
    int a,
    int b,
    SurveyPoint pa,
    SurveyPoint pb,
    Offset origin,
    Path shared,
    Path hull,
  ) {
    final key = _edgeKey(a, b);
    final count = counts[key] ?? 1;
    if (count < 0) return;
    counts[key] = -1;
    (count > 1 ? shared : hull)
      ..moveTo(pa.x - origin.dx, pa.y - origin.dy)
      ..lineTo(pb.x - origin.dx, pb.y - origin.dy);
  }

  static ({Path minor, Path major, List<ContourLabelSpec> labels})
  _buildContours(
    List<Contour> contours,
    Offset origin,
    List<SurveyPoint> survey,
  ) {
    final anchor = IndexedLabelAnchor(survey);
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
        final mid = c.points[anchor.indexFor(c.points)];
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
