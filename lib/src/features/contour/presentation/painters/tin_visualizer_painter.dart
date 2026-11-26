import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../../domain/entities/geometry.dart';
import '../../domain/entities/triangle.dart';

/// Anime.js easing functions used by the reference timeline.
abstract final class TinEasing {
  /// `easeOutElastic(1, .6)`.
  static double outElastic(
    double t, {
    double amplitude = 1,
    double period = 0.6,
  }) => 1 - _inElastic(1 - t, amplitude, period);

  static double _inElastic(double t, double a, double p) {
    if (t == 0 || t == 1) return t;
    final s = p / (2 * math.pi) * math.asin(1 / a);
    return -a *
        math.pow(2, 10 * (t - 1)) *
        math.sin(((t - 1) - s) * (2 * math.pi) / p);
  }

  static double inOutQuad(double t) =>
      t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;

  static double inOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;
}

/// Timing of the four Anime.js phases (reference lines 1510–1565).
final class TinTimeline {
  TinTimeline({
    required this.pointCount,
    required this.triangleCount,
    required this.edgeCount,
  }) : triangleStagger = math.max(
         10,
         math.min(40, triangleCount == 0 ? 40 : 800 / triangleCount),
       );

  final int pointCount;
  final int triangleCount;
  final int edgeCount;
  final double triangleStagger;

  static const double pointDuration = 800;
  static const double pointStagger = 50;
  static const double triangleStart = 500;
  static const double triangleDuration = 600;
  static const double edgeStart = 1100;
  static const double edgeStagger = 80;
  static const double edgeDuration = 600;
  static const double pulseStart = 1700;
  static const double pulseStagger = 25;
  static const double pulseDuration = 300;

  /// Delay of element [i] of [n] for `anime.stagger(step, {from: 'center'})`.
  static double centerDelay(int i, int n, double step) =>
      ((n - 1) / 2 - i).abs() * step;

  /// Total timeline length in milliseconds.
  double get totalMs {
    var end = 0.0;
    if (pointCount > 0) {
      end = math.max(
        end,
        math.max(
          pointDuration + centerDelay(0, pointCount, pointStagger),
          pulseStart + (pointCount - 1) * pulseStagger + pulseDuration,
        ),
      );
    }
    if (triangleCount > 0) {
      end = math.max(
        end,
        triangleStart +
            centerDelay(0, triangleCount, triangleStagger) +
            triangleDuration,
      );
    }
    if (edgeCount > 0) {
      end = math.max(
        end,
        edgeStart + (edgeCount - 1) * edgeStagger + edgeDuration,
      );
    }
    return math.max(end, 1);
  }

  static double progress(double t, double start, double delay, double dur) =>
      ((t - start - delay) / dur).clamp(0.0, 1.0);
}

/// One breakline segment in canvas coordinates.
final class TinEdge {
  TinEdge(this.a, this.b) : length = (b - a).distance;

  final Offset a;
  final Offset b;
  final double length;
}

typedef _Fit = ({double minX, double minY, double scale, double ox, double oy});

/// Canvas-space geometry of the visualizer for a given size.
final class TinVisualData {
  TinVisualData({
    required List<SurveyPoint> points,
    required List<Triangle> triangles,
    required List<BreakLine> breakLines,
    required this.size,
    required this.expanded,
  }) : triangles = _project(points, triangles, size, expanded),
       edges = _edges(points, breakLines, size, expanded),
       dots = _dots(points, size, expanded);

  final Size size;
  final bool expanded;
  final List<List<Offset>> triangles;
  final List<TinEdge> edges;
  final List<Offset> dots;

  TinTimeline get timeline => TinTimeline(
    pointCount: dots.length,
    triangleCount: triangles.length,
    edgeCount: edges.length,
  );

  static _Fit _fit(
    List<SurveyPoint> points,
    Size size,
    bool expanded,
  ) {
    final padding = expanded ? 40.0 : 30.0;
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
    if (!minX.isFinite) return (minX: 0, minY: 0, scale: 1, ox: 0, oy: 0);
    final rx = maxX - minX == 0 ? 1.0 : maxX - minX;
    final ry = maxY - minY == 0 ? 1.0 : maxY - minY;
    final scale = math.min(
      (size.width - 2 * padding) / rx,
      (size.height - 2 * padding) / ry,
    );
    // Centre the mesh in the canvas on the axis that has spare room.
    final ox = (size.width - 2 * padding - rx * scale) / 2;
    final oy = (size.height - 2 * padding - ry * scale) / 2;
    return (minX: minX, minY: minY, scale: scale, ox: ox, oy: oy);
  }

  static Offset _to(
    double x,
    double y,
    _Fit f,
    Size size,
    bool expanded,
  ) {
    final padding = expanded ? 40.0 : 30.0;
    return Offset(
      padding + f.ox + (x - f.minX) * f.scale,
      size.height - (padding + f.oy + (y - f.minY) * f.scale),
    );
  }

  static List<List<Offset>> _project(
    List<SurveyPoint> points,
    List<Triangle> tris,
    Size size,
    bool expanded,
  ) {
    final f = _fit(points, size, expanded);
    return [
      for (final t in tris)
        [
          _to(t.p1.x, t.p1.y, f, size, expanded),
          _to(t.p2.x, t.p2.y, f, size, expanded),
          _to(t.p3.x, t.p3.y, f, size, expanded),
        ],
    ];
  }

  static List<TinEdge> _edges(
    List<SurveyPoint> points,
    List<BreakLine> breakLines,
    Size size,
    bool expanded,
  ) {
    final f = _fit(points, size, expanded);
    final out = <TinEdge>[];
    for (final bl in breakLines) {
      for (var j = 0; j + 1 < bl.points.length; j++) {
        final a = _to(bl.points[j].x, bl.points[j].y, f, size, expanded);
        final b = _to(
          bl.points[j + 1].x,
          bl.points[j + 1].y,
          f,
          size,
          expanded,
        );
        if ((b - a).distance > 0) out.add(TinEdge(a, b));
      }
    }
    return out;
  }

  static List<Offset> _dots(
    List<SurveyPoint> points,
    Size size,
    bool expanded,
  ) {
    final f = _fit(points, size, expanded);
    final maxPoints = expanded ? 25 : 18;
    final step = math.max(1, points.length ~/ maxPoints);
    final out = <Offset>[];
    for (var i = 0; i < points.length && out.length < maxPoints; i += step) {
      out.add(_to(points[i].x, points[i].y, f, size, expanded));
    }
    return out;
  }
}

/// Paints the TIN construction canvas.
class TinVisualizerPainter extends CustomPainter {
  TinVisualizerPainter({required this.data, this.animation})
    : timeline = data.timeline,
      super(repaint: animation);

  final TinVisualData data;
  final TinTimeline timeline;

  /// Timeline position 0..1; null paints the static full preview.
  final Animation<double>? animation;

  static const Color _purple = Color(0xFFA855F7);
  static const Color _cyan = Color(0xFF00D9FF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final a = animation;
    final t = a == null ? null : a.value * timeline.totalMs;
    _paintTriangles(canvas, t);
    _paintEdges(canvas, t);
    _paintPoints(canvas, t);
    canvas.restore();
  }

  // ---- phase 2: triangles ---------------------------------------------------

  void _paintTriangles(Canvas canvas, double? t) {
    final n = data.triangles.length;
    for (var i = 0; i < n; i++) {
      final p = t == null
          ? 1.0
          : TinEasing.inOutQuad(
              TinTimeline.progress(
                t,
                TinTimeline.triangleStart,
                TinTimeline.centerDelay(i, n, timeline.triangleStagger),
                TinTimeline.triangleDuration,
              ),
            );
      if (p > 0) _paintTriangle(canvas, data.triangles[i], p);
    }
  }

  // Reused across the (up to tens of thousands of) triangles of a frame: the
  // canvas records paint and path by value on every draw call.
  final Paint _fill = Paint();
  final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Path _poly = Path();

  void _paintTriangle(Canvas canvas, List<Offset> tri, double p) {
    final poly = _poly
      ..reset()
      ..moveTo(tri[0].dx, tri[0].dy)
      ..lineTo(tri[1].dx, tri[1].dy)
      ..lineTo(tri[2].dx, tri[2].dy)
      ..close();
    _fill.color = _purple.withValues(alpha: 0.08 * p);
    canvas.drawPath(poly, _fill);
    _outline.color = _purple.withValues(alpha: 0.6 * p);
    canvas.drawPath(p >= 1 ? poly : _partialPerimeter(tri, p), _outline);
  }

  /// First [fraction] of the closed outline (anime `setDashoffset`).
  Path _partialPerimeter(List<Offset> tri, double fraction) {
    final pts = [tri[0], tri[1], tri[2], tri[0]];
    var total = 0.0;
    for (var i = 0; i < 3; i++) {
      total += (pts[i + 1] - pts[i]).distance;
    }
    var remaining = total * fraction;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < 3 && remaining > 0; i++) {
      final len = (pts[i + 1] - pts[i]).distance;
      final use = math.min(len, remaining);
      final end = len == 0
          ? pts[i]
          : pts[i] + (pts[i + 1] - pts[i]) * (use / len);
      path.lineTo(end.dx, end.dy);
      remaining -= use;
    }
    return path;
  }

  // ---- phase 3: breakline edges ---------------------------------------------

  void _paintEdges(Canvas canvas, double? t) {
    for (var i = 0; i < data.edges.length; i++) {
      final p = t == null
          ? 1.0
          : TinEasing.inOutQuad(
              TinTimeline.progress(
                t,
                TinTimeline.edgeStart,
                i * TinTimeline.edgeStagger,
                TinTimeline.edgeDuration,
              ),
            );
      if (p > 0) _paintEdge(canvas, data.edges[i], p);
    }
  }

  void _paintEdge(Canvas canvas, TinEdge e, double p) {
    // The 3px bar is positioned by its top-left corner and rotated about its
    // left-centre, so its centre line sits 1.5px below the data line.
    final dir = (e.b - e.a) / e.length;
    final start = e.a + const Offset(0, 1.5);
    final end = start + dir * (e.length * p);
    final glow = Paint()
      ..color = const Color(0xFFFF6B35).withValues(alpha: 0.6 * p)
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final bar = Paint()
      ..strokeWidth = 3
      ..shader = ui.Gradient.linear(start, end, [
        const Color(0xFFFF6B35).withValues(alpha: p),
        const Color(0xFFFF4757).withValues(alpha: p),
      ]);
    canvas
      ..drawLine(start, end, glow)
      ..drawLine(start, end, bar);
  }

  // ---- phases 1 and 4: points -----------------------------------------------

  void _paintPoints(Canvas canvas, double? t) {
    final n = data.dots.length;
    for (var i = 0; i < n; i++) {
      var opacity = 1.0;
      var scale = 1.0;
      var dy = 0.0;
      if (t != null) {
        final q = TinTimeline.progress(
          t,
          0,
          TinTimeline.centerDelay(i, n, TinTimeline.pointStagger),
          TinTimeline.pointDuration,
        );
        final e = TinEasing.outElastic(q);
        opacity = e.clamp(0.0, 1.0);
        scale = e;
        dy = -30 * (1 - e);
        scale = _pulse(t, i, scale);
      }
      if (opacity > 0 && scale > 0) {
        _paintPoint(canvas, data.dots[i] + Offset(0, dy), scale, opacity);
      }
    }
  }

  /// Phase 4 keyframes `scale: [1, 1.4, 1]`, each half eased with sine.
  double _pulse(double t, int i, double base) {
    final start = TinTimeline.pulseStart + i * TinTimeline.pulseStagger;
    if (t < start) return base;
    final q = TinTimeline.progress(t, start, 0, TinTimeline.pulseDuration);
    if (q < 0.5) {
      return 1 + 0.4 * TinEasing.inOutSine(q * 2);
    }
    return 1.4 - 0.4 * TinEasing.inOutSine((q - 0.5) * 2);
  }

  void _paintPoint(Canvas canvas, Offset c, double scale, double opacity) {
    canvas
      ..drawCircle(
        c,
        5 * scale,
        Paint()
          ..color = _cyan.withValues(alpha: 0.7 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawCircle(
        c,
        5 * scale,
        Paint()..color = _cyan.withValues(alpha: opacity),
      );
  }

  @override
  bool shouldRepaint(TinVisualizerPainter old) =>
      !identical(old.data, data) || !identical(old.animation, animation);
}
