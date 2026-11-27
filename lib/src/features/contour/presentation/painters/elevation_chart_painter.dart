import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import 'chart_data.dart';
import 'chart_math.dart';
import 'chart_tooltip.dart';
import 'viz_style.dart';

/// Look of the two Highcharts elevation variants (sidebar and modal).
@immutable
final class ElevationChartStyle {
  const ElevationChartStyle._({
    required this.height,
    required this.title,
    required this.axisTitleSize,
    required this.axisTitleColor,
    required this.xTitle,
    required this.labelSize,
    required this.yDecimals,
    required this.markerLimit,
    required this.markerRadius,
    required this.markerLine,
    required this.fillStops,
    required this.tooltipSize,
    required this.expanded,
  });

  /// Sidebar chart (reference line 2990).
  static const ElevationChartStyle compact = ElevationChartStyle._(
    height: 200,
    title: false,
    axisTitleSize: 10,
    axisTitleColor: AppColors.textMuted,
    xTitle: 'Point Index',
    labelSize: 9,
    yDecimals: 1,
    markerLimit: 20,
    markerRadius: 3,
    markerLine: 1,
    fillStops: [0.5, 0.2],
    tooltipSize: 11,
    expanded: false,
  );

  /// Expanded modal chart (reference line 3109).
  static const ElevationChartStyle large = ElevationChartStyle._(
    height: 400,
    title: true,
    axisTitleSize: 12,
    axisTitleColor: AppColors.textSecondary,
    xTitle: 'Point Index (sorted by elevation)',
    labelSize: 10,
    yDecimals: 2,
    markerLimit: 50,
    markerRadius: 4,
    markerLine: 2,
    fillStops: [0.6, 0.2],
    tooltipSize: 12,
    expanded: true,
  );

  final double height;
  final bool title;
  final double axisTitleSize;
  final Color axisTitleColor;
  final String xTitle;
  final double labelSize;
  final int yDecimals;
  final int markerLimit;
  final double markerRadius;
  final double markerLine;
  final List<double> fillStops;
  final double tooltipSize;
  final bool expanded;
}

/// Plot geometry and axes shared by painting and hit-testing.
final class ElevationChartLayout {
  ElevationChartLayout(this.size, this.samples, this.style) {
    final zs = [for (final s in samples) s.z];
    dataMin = zs.reduce(math.min);
    dataMax = zs.reduce(math.max);
    final range = dataMax - dataMin;
    final top = style.title ? 74.0 : 10.0;
    final labelH = style.labelSize + 12;
    final titleH = style.axisTitleSize + 12;
    final bottom = 10 + labelH + titleH;
    final plotH = math.max(1.0, size.height - top - bottom);
    y = style.expanded
        ? ChartMath.valueAxis(dataMin, dataMax, plotH)
        : ChartMath.valueAxis(
            dataMin,
            dataMax,
            plotH,
            explicitMin: (dataMin - range * 0.1).floorToDouble(),
            explicitMax: (dataMax + range * 0.1).ceilToDouble(),
          );
    final labelW = _maxLabelWidth();
    final left = 10 + titleH + labelW + 6;
    plot = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - 12),
      top + plotH,
    );
    final n = samples.length;
    x = style.expanded
        ? ChartMath.indexAxis(n - 1, plot.width)
        : ChartMath.indexAxis(n - 1, plot.width, interval: (n / 5).ceil());
  }

  final Size size;
  final List<ElevationSample> samples;
  final ElevationChartStyle style;
  late final double dataMin;
  late final double dataMax;
  late final AxisScale y;
  late final AxisScale x;
  late final Rect plot;

  double _maxLabelWidth() {
    var w = 0.0;
    for (final t in y.ticks) {
      final tp = VizStyle.label(
        ChartMath.fixed(t, style.yDecimals),
        VizStyle.sans(style.labelSize, AppColors.textSecondary),
      );
      w = math.max(w, tp.width);
      tp.dispose();
    }
    return w;
  }

  /// Screen position of every sample (computed once per layout).
  late final List<Offset> points = [
    for (var i = 0; i < samples.length; i++) pointAt(i),
  ];

  /// The spline through [points] (computed once per layout; callers must not
  /// mutate it).
  late final Path curve = ChartMath.spline(points);

  /// Highest plot position of the curve (smallest y).
  late final double curveTop = points.map((p) => p.dy).reduce(math.min);

  double xAt(int i) {
    final last = samples.length - 1;
    if (last <= 0) return plot.left + plot.width / 2;
    return plot.left + plot.width * i / last;
  }

  double yAt(double z) => plot.bottom - plot.height * (z - y.min) / y.span;

  Offset pointAt(int i) => Offset(xAt(i), yAt(samples[i].z));

  /// Nearest sample to the horizontal position [dx], or null outside the plot.
  int? indexAt(double dx) {
    if (dx < plot.left - 8 || dx > plot.right + 8) return null;
    final last = samples.length - 1;
    if (last <= 0) return 0;
    final t = ((dx - plot.left) / plot.width * last).round();
    return t.clamp(0, last);
  }
}

/// Highcharts `areaspline` elevation profile (reference lines 2986–3030 and
/// 3105–3148).
class ElevationChartPainter extends CustomPainter {
  ElevationChartPainter({
    required this.samples,
    required this.style,
    this.hoverIndex,
    this.layout,
  });

  final List<ElevationSample> samples;
  final ElevationChartStyle style;
  final int? hoverIndex;

  /// Optional precomputed layout for the same samples/style (reused while the
  /// pointer moves; ignored when its size differs from the paint size).
  final ElevationChartLayout? layout;

  static const Color _line = AppColors.accentCyan;
  static const Color _axisLine = Color(0xFFCCD6EB);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.isEmpty) return;
    final given = layout;
    final l = given != null &&
            given.size == size &&
            identical(given.samples, samples) &&
            given.style == style
        ? given
        : ElevationChartLayout(size, samples, style);
    _paintGrid(canvas, l);
    if (!style.expanded) _paintBand(canvas, l);
    canvas
      ..save()
      ..clipRect(l.plot.inflate(1));
    _paintArea(canvas, l);
    canvas.restore();
    _paintAxes(canvas, l);
    if (style.expanded) _paintMeanLine(canvas, l);
    _paintMarkers(canvas, l);
    if (style.title) _paintTitles(canvas, size);
    _paintHover(canvas, l, size);
  }

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;

  void _paintGrid(Canvas canvas, ElevationChartLayout l) {
    final grid = _stroke(AppColors.border, 1);
    for (final t in l.y.ticks) {
      final yy = l.yAt(t).roundToDouble() + 0.5;
      canvas.drawLine(Offset(l.plot.left, yy), Offset(l.plot.right, yy), grid);
    }
    for (final t in l.x.ticks) {
      final xx =
          (l.plot.left + l.plot.width * t / l.x.span).roundToDouble() + 0.5;
      canvas.drawLine(Offset(xx, l.plot.top), Offset(xx, l.plot.bottom), grid);
    }
  }

  void _paintBand(Canvas canvas, ElevationChartLayout l) {
    final mid = (l.dataMin + l.dataMax) / 2;
    final rect = Rect.fromLTRB(
      l.plot.left,
      l.yAt(mid),
      l.plot.right,
      l.yAt(l.dataMin),
    );
    canvas.drawRect(rect, Paint()..color = const Color(0x0D00D9FF));
    VizStyle.drawText(
      canvas,
      'Lower',
      VizStyle.sans(8, AppColors.textMuted),
      Offset(rect.left + 4, rect.top + 2),
    );
  }

  void _paintArea(Canvas canvas, ElevationChartLayout l) {
    final pts = l.points;
    final curve = l.curve;
    final fill = Path.from(curve)
      ..lineTo(pts.last.dx, l.plot.bottom)
      ..lineTo(pts.first.dx, l.plot.bottom)
      ..close();
    final top = l.curveTop;
    final shader = ui.Gradient.linear(
      Offset(0, top),
      Offset(0, l.plot.bottom),
      [
        _line.withValues(alpha: style.fillStops[0]),
        _line.withValues(alpha: style.fillStops[1]),
        _line.withValues(alpha: 0),
      ],
      const [0, 0.5, 1],
    );
    canvas
      ..drawPath(fill, Paint()..shader = shader)
      ..drawPath(curve, _stroke(_line, 2));
  }

  void _paintAxes(Canvas canvas, ElevationChartLayout l) {
    canvas.drawLine(
      Offset(l.plot.left, l.plot.bottom + 0.5),
      Offset(l.plot.right, l.plot.bottom + 0.5),
      _stroke(_axisLine, 1),
    );
    final labelStyle = VizStyle.sans(style.labelSize, AppColors.textSecondary);
    for (final t in l.x.ticks) {
      final xx = l.plot.left + l.plot.width * t / l.x.span;
      canvas.drawLine(
        Offset(xx.roundToDouble() + 0.5, l.plot.bottom),
        Offset(xx.roundToDouble() + 0.5, l.plot.bottom + 10),
        _stroke(_axisLine, 1),
      );
      VizStyle.drawText(
        canvas,
        t.toStringAsFixed(0),
        labelStyle,
        Offset(xx, l.plot.bottom + 14),
        align: TextAlign.center,
      );
    }
    for (final t in l.y.ticks) {
      final tp = VizStyle.label(
        ChartMath.fixed(t, style.yDecimals),
        labelStyle,
      );
      tp.paint(
        canvas,
        Offset(l.plot.left - 6 - tp.width, l.yAt(t) - tp.height / 2),
      );
      tp.dispose();
    }
    _paintAxisTitles(canvas, l);
  }

  void _paintAxisTitles(Canvas canvas, ElevationChartLayout l) {
    final s = VizStyle.sans(style.axisTitleSize, style.axisTitleColor);
    VizStyle.drawText(
      canvas,
      style.xTitle,
      s,
      Offset(
        (l.plot.left + l.plot.right) / 2,
        l.size.height - 10 - style.axisTitleSize - 2,
      ),
      align: TextAlign.center,
    );
    final tp = VizStyle.label('Elevation (m)', s);
    canvas
      ..save()
      ..translate(10, (l.plot.top + l.plot.bottom) / 2 + tp.width / 2)
      ..rotate(-math.pi / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
    tp.dispose();
  }

  void _paintMeanLine(Canvas canvas, ElevationChartLayout l) {
    final yy = l.yAt((l.dataMin + l.dataMax) / 2);
    const purple = AppColors.accentPurple;
    final dashed = dashedPolyline(
      [Offset(l.plot.left, yy), Offset(l.plot.right, yy)],
      8,
      6,
    );
    canvas.drawPath(dashed, _stroke(purple, 1));
    final tp = VizStyle.label('Mean', VizStyle.sans(10, purple));
    tp.paint(canvas, Offset(l.plot.left + 4, yy - tp.height - 2));
    tp.dispose();
  }

  void _paintMarkers(Canvas canvas, ElevationChartLayout l) {
    if (samples.length >= style.markerLimit) return;
    final fill = Paint()..color = _line;
    final edge = _stroke(AppColors.bgPrimary, style.markerLine);
    for (var i = 0; i < samples.length; i++) {
      final p = l.pointAt(i);
      canvas
        ..drawCircle(p, style.markerRadius, fill)
        ..drawCircle(p, style.markerRadius, edge);
    }
  }

  void _paintTitles(Canvas canvas, Size size) {
    final range = [for (final s in samples) s.z];
    final span = range.reduce(math.max) - range.reduce(math.min);
    VizStyle.drawText(
      canvas,
      'Elevation Profile (Sorted)',
      VizStyle.sans(16, AppColors.textPrimary),
      Offset(size.width / 2, 12),
      align: TextAlign.center,
    );
    VizStyle.drawText(
      canvas,
      '${samples.length} survey points | Range: ${ChartMath.fixed(span, 2)}m',
      VizStyle.sans(12, AppColors.textSecondary),
      Offset(size.width / 2, 38),
      align: TextAlign.center,
    );
  }

  void _paintHover(Canvas canvas, ElevationChartLayout l, Size size) {
    final i = hoverIndex;
    if (i == null || i < 0 || i >= samples.length) return;
    final p = l.pointAt(i);
    final r = style.markerRadius + 2;
    canvas
      ..drawCircle(p, r, Paint()..color = _line)
      ..drawCircle(p, r, _stroke(AppColors.bgPrimary, style.markerLine));
    final s = samples[i];
    final lines = style.expanded
        ? [
            [TooltipRun(s.name, bold: true)],
            [
              const TooltipRun('Elevation: '),
              TooltipRun('${ChartMath.fixed(s.z, 3)} m', bold: true),
            ],
          ]
        : [
            [TooltipRun('Point ${i + 1}', bold: true)],
            [
              const TooltipRun('Elevation: '),
              TooltipRun('${ChartMath.fixed(s.z, 2)} m', bold: true),
            ],
          ];
    ChartTooltip.paint(canvas, size, p, lines, fontSize: style.tooltipSize);
  }

  @override
  bool shouldRepaint(ElevationChartPainter old) =>
      !identical(old.samples, samples) ||
      old.style != style ||
      old.hoverIndex != hoverIndex;
}
