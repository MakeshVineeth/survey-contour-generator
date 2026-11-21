import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/js_number.dart';
import '../../domain/entities/geometry.dart';
import 'map_geometry.dart';
import 'viz_style.dart';

/// Which layers [MapPainter] draws (Layers tab toggles).
@immutable
final class MapLayers {
  const MapLayers({
    required this.tin,
    required this.contours,
    required this.breakLines,
    required this.labels,
  });

  final bool tin;
  final bool contours;
  final bool breakLines;
  final bool labels;

  @override
  bool operator ==(Object other) =>
      other is MapLayers &&
      other.tin == tin &&
      other.contours == contours &&
      other.breakLines == breakLines &&
      other.labels == labels;

  @override
  int get hashCode => Object.hash(tin, contours, breakLines, labels);
}

/// Screen mapping: `screen = half + (world - center) * scale`, Y flipped.
final class _MapView {
  _MapView(this.size, this.geometry, double cx, double cy, this.scale)
    : dx = cx - geometry.originX,
      dy = cy - geometry.originY;

  final Size size;
  final MapGeometry geometry;
  final double scale;
  final double dx;
  final double dy;

  double get halfW => size.width / 2;
  double get halfH => size.height / 2;

  Offset toScreen(Offset rel) =>
      Offset(halfW + (rel.dx - dx) * scale, halfH - (rel.dy - dy) * scale);

  Offset pointToScreen(Point3 p) =>
      toScreen(Offset(p.x - geometry.originX, p.y - geometry.originY));

  bool visible(Offset s, [double margin = 60]) =>
      s.dx > -margin &&
      s.dy > -margin &&
      s.dx < size.width + margin &&
      s.dy < size.height + margin;
}

/// The interactive map (reference canvas render, lines 1763–1951).
class MapPainter extends CustomPainter {
  MapPainter({
    required this.geometry,
    required this.centerX,
    required this.centerY,
    required this.scale,
    required this.layers,
    required this.drawMode,
    required this.currentBreakline,
  });

  final MapGeometry geometry;
  final double centerX;
  final double centerY;
  final double scale;
  final MapLayers layers;
  final bool drawMode;
  final List<Point3> currentBreakline;

  static const Color _tinColor = Color(0xFF6366F1);
  static const Color _minor = AppColors.accentGreen;
  static const Color _major = AppColors.accentRed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bgPrimary);
    final view = _MapView(size, geometry, centerX, centerY, scale);
    _paintGrid(canvas, view);
    if (geometry.points.isEmpty) {
      _paintEmptyState(canvas, size);
    } else {
      _paintData(canvas, view);
    }
    canvas.restore();
  }

  void _paintData(Canvas canvas, _MapView view) {
    if (layers.tin && geometry.triangles.isNotEmpty) _paintTin(canvas, view);
    if (layers.breakLines) _paintBreakLines(canvas, view);
    if (drawMode && currentBreakline.isNotEmpty) _paintDrawing(canvas, view);
    if (layers.contours) _paintContours(canvas, view);
    _paintPoints(canvas, view);
  }

  // ---- grid -----------------------------------------------------------------

  void _paintGrid(Canvas canvas, _MapView view) {
    final worldSize = math
        .pow(10, (math.log(100 / scale) / math.ln10).floorToDouble())
        .toDouble();
    final screenSize = worldSize * scale;
    if (!(screenSize > 10)) return;
    final paint = Paint()
      ..color = AppColors.bgTertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final w = view.size.width;
    final h = view.size.height;
    final startX = ((centerX - view.halfW / scale) / worldSize).floor();
    final endX = ((centerX + view.halfW / scale) / worldSize).ceil();
    final startY = ((centerY - view.halfH / scale) / worldSize).floor();
    final endY = ((centerY + view.halfH / scale) / worldSize).ceil();
    for (var i = startX; i <= endX; i++) {
      final sx = view.halfW + (i * worldSize - centerX) * scale;
      canvas.drawLine(Offset(sx, 0), Offset(sx, h), paint);
    }
    for (var i = startY; i <= endY; i++) {
      final sy = view.halfH - (i * worldSize - centerY) * scale;
      canvas.drawLine(Offset(0, sy), Offset(w, sy), paint);
    }
  }

  void _paintEmptyState(Canvas canvas, Size size) {
    final tp = VizStyle.label(
      'Import survey data to begin',
      VizStyle.sans(16, AppColors.textMuted),
    );
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, size.height / 2 - tp.height * 0.75),
    );
    tp.dispose();
  }

  // ---- layers in world space (cached paths) ---------------------------------

  void _withWorldTransform(Canvas canvas, _MapView view, VoidCallback draw) {
    canvas
      ..save()
      ..translate(view.halfW - view.dx * scale, view.halfH + view.dy * scale)
      ..scale(scale, -scale);
    draw();
    canvas.restore();
  }

  Paint _worldStroke(Color color, double widthPx) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = widthPx / scale;

  void _paintTin(Canvas canvas, _MapView view) {
    _withWorldTransform(canvas, view, () {
      canvas
        ..drawPath(
          geometry.tinShared,
          _worldStroke(_tinColor.withValues(alpha: 0.51), 0.5),
        )
        ..drawPath(
          geometry.tinHull,
          _worldStroke(_tinColor.withValues(alpha: 0.3), 0.5),
        );
    });
  }

  void _paintContours(Canvas canvas, _MapView view) {
    _withWorldTransform(canvas, view, () {
      canvas
        ..drawPath(geometry.minor, _worldStroke(_minor, 1))
        ..drawPath(geometry.major, _worldStroke(_major, 2));
    });
    if (layers.labels) _paintContourLabels(canvas, view);
  }

  void _paintContourLabels(Canvas canvas, _MapView view) {
    final bg = Paint()..color = AppColors.bgPrimary;
    for (final label in geometry.contourLabels) {
      final mid = view.toScreen(label.position);
      if (!view.visible(mid)) continue;
      final tp = label.painter;
      canvas.drawRect(
        Rect.fromLTWH(mid.dx - tp.width / 2 - 2, mid.dy - 6, tp.width + 4, 12),
        bg,
      );
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    }
  }

  // ---- breaklines -----------------------------------------------------------

  void _paintBreakLines(Canvas canvas, _MapView view) {
    final line = Paint()
      ..color = AppColors.accentOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final dot = Paint()..color = AppColors.accentOrange;
    for (final poly in geometry.breakLinePolys) {
      final pts = [for (final p in poly) view.toScreen(p)];
      canvas.drawPath(dashedPolyline(pts, 8, 4), line);
      for (final p in pts) {
        if (view.visible(p, 10)) canvas.drawCircle(p, 4, dot);
      }
    }
  }

  void _paintDrawing(Canvas canvas, _MapView view) {
    final pts = [for (final p in currentBreakline) view.pointToScreen(p)];
    canvas.drawPath(
      dashedPolyline(pts, 5, 5),
      Paint()
        ..color = AppColors.accentOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (var i = 0; i < pts.length; i++) {
      _paintDrawingPoint(canvas, pts[i], i + 1, currentBreakline[i].z);
    }
  }

  void _paintDrawingPoint(Canvas canvas, Offset sp, int number, double z) {
    canvas
      ..drawCircle(sp, 7, Paint()..color = AppColors.accentYellow)
      ..drawCircle(
        sp,
        7,
        Paint()
          ..color = AppColors.accentOrange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    final index = VizStyle.label(
      '$number',
      VizStyle.mono(
        10,
        AppColors.bgPrimary,
        weight: FontWeight.w700,
        height: 1,
      ),
    );
    index.paint(canvas, sp - Offset(index.width / 2, index.height / 2));
    index.dispose();
    final rl = VizStyle.label(
      'RL ${z.toFixed(2)}',
      VizStyle.mono(10, AppColors.accentGreen, height: 1),
    );
    rl.paint(canvas, Offset(sp.dx + 10, sp.dy - 4 - rl.height));
    rl.dispose();
  }

  // ---- survey points --------------------------------------------------------

  void _paintPoints(Canvas canvas, _MapView view) {
    final fill = Paint()..color = AppColors.accentCyan;
    final edge = Paint()
      ..color = AppColors.bgPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rel = geometry.pointRel;
    for (var i = 0; i < rel.length; i++) {
      final sp = view.toScreen(rel[i]);
      if (!view.visible(sp, 40)) continue;
      canvas
        ..drawCircle(sp, 5, fill)
        ..drawCircle(sp, 5, edge);
      if (layers.labels) _paintPointLabels(canvas, sp, i);
    }
  }

  void _paintPointLabels(Canvas canvas, Offset sp, int i) {
    final bh = geometry.boreholeLabel(i);
    bh.paint(canvas, Offset(sp.dx - bh.width / 2, sp.dy - 8 - bh.height));
    final rl = geometry.levelLabel(i);
    rl.paint(canvas, Offset(sp.dx - rl.width / 2, sp.dy + 8));
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      !identical(old.geometry, geometry) ||
      old.centerX != centerX ||
      old.centerY != centerY ||
      old.scale != scale ||
      old.layers != layers ||
      old.drawMode != drawMode ||
      !identical(old.currentBreakline, currentBreakline);
}
