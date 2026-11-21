import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/js_number.dart';
import 'chart_data.dart';
import 'chart_tooltip.dart';
import 'viz_style.dart';

/// Geometry of the donut: centre, radii and the angular span of each slice.
final class SlopeChartLayout {
  SlopeChartLayout(this.size, this.bins, {required this.expanded}) {
    final top = expanded ? 62.0 : 0.0;
    final availH = size.height - top;
    center = Offset(size.width / 2, top + availH / 2);
    final byLabels =
        size.width / 2 - (expanded ? 25 : 15) - (expanded ? 110 : 62);
    if (expanded) {
      outer = math.max(
        30,
        math.min(0.425 * math.min(size.width, availH), byLabels + 25),
      );
    } else {
      outer = math.max(28, math.min(availH / 2 - 34, byLabels));
    }
    inner = outer * (expanded ? 0.5 : 0.55);
    var total = 0;
    for (final b in bins) {
      total += b.count;
    }
    this.total = total;
    var angle = -math.pi / 2;
    final list = <({double start, double sweep})>[];
    for (final b in bins) {
      final sweep = total == 0 ? 0.0 : 2 * math.pi * b.count / total;
      list.add((start: angle, sweep: sweep));
      angle += sweep;
    }
    slices = list;
  }

  final Size size;
  final List<SlopeBin> bins;
  final bool expanded;
  late final Offset center;
  late final double outer;
  late final double inner;
  late final int total;
  late final List<({double start, double sweep})> slices;

  double mid(int i) => slices[i].start + slices[i].sweep / 2;

  Offset centroid(int i) {
    final r = (outer + inner) / 2;
    return center + Offset(math.cos(mid(i)) * r, math.sin(mid(i)) * r);
  }

  /// Slice under [p], or null.
  int? hitTest(Offset p) {
    final d = p - center;
    final dist = d.distance;
    if (dist < inner || dist > outer + (expanded ? 5 : 8)) return null;
    var a = math.atan2(d.dy, d.dx);
    if (a < -math.pi / 2) a += 2 * math.pi;
    for (var i = 0; i < slices.length; i++) {
      final s = slices[i];
      if (a >= s.start && a < s.start + s.sweep) return i;
    }
    return null;
  }
}

/// Highcharts donut of the slope classes (reference lines 3055–3095 and
/// 3177–3239).
class SlopeChartPainter extends CustomPainter {
  SlopeChartPainter({
    required this.analysis,
    required this.expanded,
    this.hoverIndex,
  });

  final SlopeAnalysis analysis;
  final bool expanded;
  final int? hoverIndex;

  List<SlopeBin> get _bins => analysis.nonEmpty;

  @override
  void paint(Canvas canvas, Size size) {
    final bins = _bins;
    if (bins.isEmpty || size.isEmpty) return;
    final l = SlopeChartLayout(size, bins, expanded: expanded);
    for (var i = 0; i < bins.length; i++) {
      _paintSlice(canvas, l, i);
    }
    _paintLabels(canvas, l);
    if (expanded) _paintTitles(canvas, size);
    _paintTooltip(canvas, l, size);
  }

  Color _colorOf(SlopeBin b, bool hover) {
    final c = Color(b.color);
    if (!hover) return c;
    return Color.lerp(c, const Color(0xFFFFFFFF), expanded ? 0.15 : 0.1)!;
  }

  void _paintSlice(Canvas canvas, SlopeChartLayout l, int i) {
    final b = l.bins[i];
    final s = l.slices[i];
    final hover = hoverIndex == i;
    final grow = hover && expanded ? 5.0 : 0.0;
    final outer = l.outer + grow;
    final path = _ring(l.center, outer, l.inner, s.start, s.sweep);
    if (hover) _paintHalo(canvas, l, i, outer);
    final fill = Paint();
    if (expanded) {
      fill.shader = ui.Gradient.linear(
        l.center - Offset(outer, outer),
        l.center + Offset(outer, outer),
        [_colorOf(b, hover), Color(b.gradientEnd)],
      );
    } else {
      fill.color = _colorOf(b, hover);
    }
    canvas
      ..drawPath(path, fill)
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.bgPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = expanded ? 3 : 2,
      );
  }

  /// Annular sector between [inner] and [outer]. A slice covering the whole
  /// circle (a single class at 100%) cannot be built from arcs - a 360 degree
  /// sweep collapses to nothing - so it is drawn as a ring instead.
  static Path _ring(
    Offset center,
    double outer,
    double inner,
    double start,
    double sweep,
  ) {
    final outerRect = Rect.fromCircle(center: center, radius: outer);
    final innerRect = Rect.fromCircle(center: center, radius: inner);
    if (sweep >= 2 * math.pi - 1e-6) {
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(outerRect)
        ..addOval(innerRect);
    }
    return Path()
      ..arcTo(outerRect, start, sweep, true)
      ..arcTo(innerRect, start + sweep, -sweep, false)
      ..close();
  }

  void _paintHalo(Canvas canvas, SlopeChartLayout l, int i, double outer) {
    final halo = expanded ? 12.0 : 8.0;
    final s = l.slices[i];
    final path = _ring(l.center, outer + halo, outer, s.start, s.sweep);
    canvas.drawPath(
      path,
      Paint()..color = Color(l.bins[i].color).withValues(alpha: 0.25),
    );
  }

  // ---- data labels ------------------------------------------------------------

  void _paintLabels(Canvas canvas, SlopeChartLayout l) {
    final distance = expanded ? 25.0 : 15.0;
    final maxW = expanded ? 120.0 : 62.0;
    final labels = <_Label>[];
    for (var i = 0; i < l.bins.length; i++) {
      final a = l.mid(i);
      final right = math.cos(a) >= 0;
      final anchor =
          l.center +
          Offset(
            math.cos(a) * (l.outer + distance),
            math.sin(a) * (l.outer + distance),
          );
      final tp = _labelPainter(l, i, maxW);
      labels.add(_Label(i, a, right, anchor, tp));
    }
    _spreadVertically(labels, l.size.height);
    for (final lb in labels) {
      _paintLabel(canvas, l, lb);
      lb.painter.dispose();
    }
  }

  TextPainter _labelPainter(SlopeChartLayout l, int i, double maxW) {
    final b = l.bins[i];
    final pct = (b.count / l.total * 100).toFixed(1);
    final size = expanded ? 11.0 : 9.0;
    final detail = expanded ? '${b.count} ($pct%)' : '$pct%';
    final style = VizStyle.sans(
      size,
      AppColors.textPrimary,
      weight: expanded ? FontWeight.w500 : FontWeight.w400,
    );
    final tp = TextPainter(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: b.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: '\n$detail'),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout(maxWidth: maxW);
    return tp;
  }

  void _spreadVertically(List<_Label> labels, double height) {
    for (final right in [true, false]) {
      final side = labels.where((e) => e.right == right).toList()
        ..sort((a, b) => a.anchor.dy.compareTo(b.anchor.dy));
      var minY = 0.0;
      for (final lb in side) {
        final h = lb.painter.height;
        lb.y = math.max(lb.anchor.dy - h / 2, minY);
        lb.y = math.min(lb.y, height - h);
        minY = lb.y + h + 2;
      }
    }
  }

  void _paintLabel(Canvas canvas, SlopeChartLayout l, _Label lb) {
    final tp = lb.painter;
    final x = lb.right ? lb.anchor.dx + 4 : lb.anchor.dx - 4 - tp.width;
    final from =
        l.center +
        Offset(math.cos(lb.angle) * l.outer, math.sin(lb.angle) * l.outer);
    final connectorColor = expanded
        ? AppColors.textMuted
        : Color(l.bins[lb.index].color);
    canvas.drawLine(
      from,
      Offset(lb.anchor.dx, lb.y + tp.height / 2),
      Paint()
        ..color = connectorColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    if (expanded) _paintOutline(canvas, lb, Offset(x, lb.y));
    tp.paint(canvas, Offset(x, lb.y));
  }

  void _paintOutline(Canvas canvas, _Label lb, Offset at) {
    final outline = TextPainter(
      text: TextSpan(
        style: VizStyle.sans(11, AppColors.textPrimary, weight: FontWeight.w500)
            .copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = AppColors.bgPrimary,
            ),
        children: [TextSpan(text: _plain(lb.painter))],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    outline
      ..paint(canvas, at)
      ..dispose();
  }

  String _plain(TextPainter tp) => tp.text?.toPlainText() ?? '';

  void _paintTitles(Canvas canvas, Size size) {
    VizStyle.drawText(
      canvas,
      'Slope Distribution Analysis',
      VizStyle.sans(18, AppColors.textPrimary, weight: FontWeight.w600),
      Offset(size.width / 2, 12),
      align: TextAlign.center,
    );
    final a = analysis;
    VizStyle.drawText(
      canvas,
      '${a.total} triangles analyzed | Avg: ${a.avg.toFixed(1)}° | '
      'Min: ${a.min.toFixed(1)}° | Max: ${a.max.toFixed(1)}°',
      VizStyle.sans(12, AppColors.textSecondary),
      Offset(size.width / 2, 40),
      align: TextAlign.center,
    );
  }

  void _paintTooltip(Canvas canvas, SlopeChartLayout l, Size size) {
    final i = hoverIndex;
    if (i == null || i < 0 || i >= l.bins.length) return;
    final b = l.bins[i];
    final pct = (b.count / l.total * 100).toFixed(1);
    final lines = expanded
        ? [
            [TooltipRun(b.name, bold: true, size: 14)],
            [
              const TooltipRun('Count: ', color: AppColors.textSecondary),
              TooltipRun('${b.count}', bold: true),
              const TooltipRun(' triangles'),
            ],
            [
              const TooltipRun('Percentage: ', color: AppColors.textSecondary),
              TooltipRun('$pct%', bold: true),
            ],
            [TooltipRun(b.description, color: AppColors.textMuted, size: 11)],
          ]
        : [
            [TooltipRun(b.name, bold: true)],
            [
              const TooltipRun('Count: '),
              TooltipRun('${b.count}', bold: true),
              TooltipRun(' ($pct%)'),
            ],
          ];
    ChartTooltip.paint(
      canvas,
      size,
      l.centroid(i),
      lines,
      fontSize: expanded ? 13 : 11,
      radius: expanded ? 8 : 3,
    );
  }

  @override
  bool shouldRepaint(SlopeChartPainter old) =>
      !identical(old.analysis, analysis) ||
      old.expanded != expanded ||
      old.hoverIndex != hoverIndex;
}

class _Label {
  _Label(this.index, this.angle, this.right, this.anchor, this.painter)
    : y = anchor.dy - painter.height / 2;

  final int index;
  final double angle;
  final bool right;
  final Offset anchor;
  final TextPainter painter;
  double y;
}
