// Verbatim copy of the original (allocation-heavy) TIN painter, kept as a
// pixel reference for the optimised painter. Do not "improve" this file.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/tin_visualizer_painter.dart';

/// Paints the TIN construction canvas.
class ReferenceTinVisualizerPainter extends CustomPainter {
  ReferenceTinVisualizerPainter({required this.data, this.animation})
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

  void _paintTriangle(Canvas canvas, List<Offset> tri, double p) {
    final poly = Path()
      ..moveTo(tri[0].dx, tri[0].dy)
      ..lineTo(tri[1].dx, tri[1].dy)
      ..lineTo(tri[2].dx, tri[2].dy)
      ..close();
    canvas.drawPath(poly, Paint()..color = _purple.withValues(alpha: 0.08 * p));
    final stroke = Paint()
      ..color = _purple.withValues(alpha: 0.6 * p)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(p >= 1 ? poly : _partialPerimeter(tri, p), stroke);
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
  bool shouldRepaint(ReferenceTinVisualizerPainter old) =>
      !identical(old.data, data) || !identical(old.animation, animation);
}
