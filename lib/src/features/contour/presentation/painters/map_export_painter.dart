import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../core/utils/js_number.dart';
import '../../domain/entities/contour.dart';
import '../../domain/entities/geometry.dart';
import '../../domain/entities/triangle.dart';
import 'map_painter.dart';
import 'viz_style.dart';

/// Everything an off-screen map rendering needs.
@immutable
final class MapExportData {
  const MapExportData({
    required this.points,
    required this.breakLines,
    required this.triangles,
    required this.contours,
    required this.layers,
  });

  final List<SurveyPoint> points;
  final List<BreakLine> breakLines;
  final List<Triangle> triangles;
  final List<Contour> contours;
  final MapLayers layers;
}

enum _Baseline { alphabetic, top, bottom, middle }

/// Fit of the data into a square canvas with 10 % padding (export/print).
final class _ExportFit {
  _ExportFit(this.size, MapExportData data) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    void add(double x, double y) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    for (final p in data.points) {
      add(p.x, p.y);
    }
    for (final bl in data.breakLines) {
      for (final p in bl.points) {
        add(p.x, p.y);
      }
    }
    if (!minX.isFinite) {
      minX = maxX = minY = maxY = 0;
    }
    final pad = size * 0.1;
    final w = maxX - minX == 0 ? 1.0 : maxX - minX;
    final h = maxY - minY == 0 ? 1.0 : maxY - minY;
    scale = math.min((size - pad * 2) / w, (size - pad * 2) / h);
    cx = (minX + maxX) / 2;
    cy = (minY + maxY) / 2;
  }

  final double size;
  late final double scale;
  late final double cx;
  late final double cy;

  Offset at(double x, double y) =>
      Offset(size / 2 + (x - cx) * scale, size / 2 - (y - cy) * scale);

  Path polyline(Iterable<Offset> pts) {
    final path = Path();
    var first = true;
    for (final p in pts) {
      if (first) {
        path.moveTo(p.dx, p.dy);
        first = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }
}

/// Off-screen renderings of the map, drawn onto a square white canvas.
///
/// [paintImage] mirrors `exportImage` (3000 px, lines 2410–2536) and
/// [paintPrint] mirrors `handlePrint` (2000 px, lines 2299–2385). Text uses
/// the bundled Outfit font instead of Arial so exports render identically on
/// every platform without system fonts.
abstract final class MapExportPainter {
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _black = Color(0xFF000000);

  static void paintImage(Canvas canvas, double size, MapExportData data) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = _white);
    final fit = _ExportFit(size, data);
    if (data.layers.tin) _imageTin(canvas, fit, data);
    if (data.layers.breakLines) _imageBreakLines(canvas, fit, data);
    if (data.layers.contours) _imageContours(canvas, fit, data);
    _imagePoints(canvas, fit, data);
  }

  static void paintPrint(
    Canvas canvas,
    double size,
    MapExportData data, {
    required DateTime generatedAt,
  }) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = _white);
    final fit = _ExportFit(size, data);
    _printContours(canvas, fit, data);
    _printBreakLines(canvas, fit, data);
    _printPoints(canvas, fit, data);
    _printTitle(canvas, data, generatedAt);
  }

  // ---- PNG / BMP ------------------------------------------------------------

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  static void _imageTin(Canvas canvas, _ExportFit fit, MapExportData data) {
    final path = Path();
    for (final t in data.triangles) {
      final a = fit.at(t.p1.x, t.p1.y);
      final b = fit.at(t.p2.x, t.p2.y);
      final c = fit.at(t.p3.x, t.p3.y);
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..close();
    }
    canvas.drawPath(path, _stroke(const Color(0xFFE0E0E0), 1));
  }

  static void _imageBreakLines(
    Canvas canvas,
    _ExportFit fit,
    MapExportData data,
  ) {
    final paint = _stroke(const Color(0xFFFF6B35), 3);
    for (final bl in data.breakLines) {
      if (bl.points.isEmpty) continue;
      canvas.drawPath(
        fit.polyline([for (final p in bl.points) fit.at(p.x, p.y)]),
        paint,
      );
    }
  }

  static void _imageContours(
    Canvas canvas,
    _ExportFit fit,
    MapExportData data,
  ) {
    const major = Color(0xFFFF4757);
    final minorPaint = _stroke(const Color(0xFF00FF88), 1.5);
    final majorPaint = _stroke(major, 3);
    for (final c in data.contours) {
      if (c.points.isEmpty) continue;
      final pts = [for (final p in c.points) fit.at(p.x, p.y)];
      canvas.drawPath(fit.polyline(pts), c.isMajor ? majorPaint : minorPaint);
      if (data.layers.labels && c.isMajor && pts.length >= 2) {
        _imageContourLabel(canvas, pts[pts.length ~/ 2], c.level);
      }
    }
  }

  static void _imageContourLabel(Canvas canvas, Offset mid, double level) {
    final tp = VizStyle.label(
      level.toFixed(1),
      VizStyle.sans(20, const Color(0xFFFF4757), weight: FontWeight.w700),
    );
    canvas.drawRect(
      Rect.fromLTWH(mid.dx - tp.width / 2 - 4, mid.dy - 12, tp.width + 8, 24),
      Paint()..color = _white,
    );
    tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    tp.dispose();
  }

  static void _imagePoints(Canvas canvas, _ExportFit fit, MapExportData data) {
    final fill = Paint()..color = const Color(0xFF00D9FF);
    final edge = _stroke(_black, 2);
    for (final pt in data.points) {
      final sp = fit.at(pt.x, pt.y);
      canvas
        ..drawCircle(sp, 8, fill)
        ..drawCircle(sp, 8, edge);
      if (!data.layers.labels) continue;
      _text(
        canvas,
        pt.borehole,
        VizStyle.sans(16, const Color(0xFF00D9FF), weight: FontWeight.w700),
        Offset(sp.dx, sp.dy - 12),
        align: TextAlign.center,
        baseline: _Baseline.bottom,
      );
      _text(
        canvas,
        'RL ${pt.z.toFixed(2)}',
        VizStyle.sans(14, const Color(0xFF00FF88)),
        Offset(sp.dx, sp.dy + 12),
        align: TextAlign.center,
        baseline: _Baseline.top,
      );
    }
  }

  // ---- print ----------------------------------------------------------------

  static void _printContours(Canvas canvas, _ExportFit fit, MapExportData d) {
    final minorPaint = _stroke(const Color(0xFF008800), 1);
    final majorPaint = _stroke(const Color(0xFFCC0000), 2);
    for (final c in d.contours) {
      final pts = [for (final p in c.points) fit.at(p.x, p.y)];
      canvas.drawPath(fit.polyline(pts), c.isMajor ? majorPaint : minorPaint);
      if (pts.length > 2) {
        _text(
          canvas,
          c.level.toFixed(1),
          VizStyle.sans(14, _black, weight: FontWeight.w700),
          pts[pts.length ~/ 2],
        );
      }
    }
  }

  static void _printBreakLines(Canvas canvas, _ExportFit fit, MapExportData d) {
    final paint = _stroke(const Color(0xFFFF00FF), 2);
    for (final bl in d.breakLines) {
      canvas.drawPath(
        fit.polyline([for (final p in bl.points) fit.at(p.x, p.y)]),
        paint,
      );
    }
  }

  static void _printPoints(Canvas canvas, _ExportFit fit, MapExportData d) {
    final fill = Paint()..color = const Color(0xFF0066CC);
    for (final pt in d.points) {
      final sp = fit.at(pt.x, pt.y);
      canvas.drawCircle(sp, 4, fill);
      _text(
        canvas,
        '${pt.borehole} (${pt.z.toFixed(2)})',
        VizStyle.sans(10, _black),
        Offset(sp.dx + 6, sp.dy + 4),
      );
    }
  }

  static void _printTitle(Canvas canvas, MapExportData d, DateTime at) {
    _text(
      canvas,
      'Survey Contour Map',
      VizStyle.sans(24, _black, weight: FontWeight.w700),
      const Offset(50, 50),
    );
    _text(
      canvas,
      'Generated: ${formatLocaleDateTime(at)} | Points: ${d.points.length} '
      '| Contours: ${d.contours.length}',
      VizStyle.sans(14, _black),
      const Offset(50, 80),
    );
  }

  /// JavaScript `toLocaleString()` in `en-US` (e.g. `3/7/2026, 4:05:09 PM`).
  static String formatLocaleDateTime(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '${t.month}/${t.day}/${t.year}, $hour12:$mm:$ss $ampm';
  }

  /// Draws one text run like canvas `fillText` with the given alignment and
  /// baseline, then releases the painter.
  static void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    TextAlign align = TextAlign.left,
    _Baseline baseline = _Baseline.alphabetic,
  }) {
    final tp = VizStyle.label(text, style);
    final dx = align == TextAlign.center ? -tp.width / 2 : 0.0;
    final dy = switch (baseline) {
      _Baseline.alphabetic => -tp.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      ),
      _Baseline.top => 0.0,
      _Baseline.bottom => -tp.height,
      _Baseline.middle => -tp.height / 2,
    };
    tp.paint(canvas, at + Offset(dx, dy));
    tp.dispose();
  }
}
