import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../../core/theme/app_colors.dart';
import 'viz_style.dart';

/// One styled run inside a tooltip line.
final class TooltipRun {
  const TooltipRun(this.text, {this.bold = false, this.color, this.size});

  final String text;
  final bool bold;
  final Color? color;
  final double? size;
}

/// Highcharts-like tooltip box: `rgba(17,24,32,0.95)` with a 1px `#2d3748`
/// border, radius [radius] and 8px padding.
abstract final class ChartTooltip {
  static const Color _background = AppColors.overlayPanel;

  /// Paints [lines] centred above [anchor] (below when there is no room),
  /// clamped to [bounds].
  static void paint(
    Canvas canvas,
    Size bounds,
    Offset anchor,
    List<List<TooltipRun>> lines, {
    required double fontSize,
    double radius = 3,
  }) {
    final tp = TextPainter(
      text: _span(lines, fontSize),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = 8.0;
    final w = tp.width + pad * 2;
    final h = tp.height + pad * 2;
    var x = anchor.dx - w / 2;
    var y = anchor.dy - h - 14;
    if (y < 0) y = anchor.dy + 14;
    x = math.max(0, math.min(bounds.width - w, x));
    y = math.max(0, math.min(bounds.height - h, y));
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(radius),
    );
    canvas
      ..drawRRect(rect, Paint()..color = _background)
      ..drawRRect(
        rect,
        Paint()
          ..color = AppColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    tp
      ..paint(canvas, Offset(x + pad, y + pad))
      ..dispose();
  }

  static TextSpan _span(List<List<TooltipRun>> lines, double fontSize) {
    final base = VizStyle.sans(fontSize, AppColors.textPrimary, height: 1.4);
    final children = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) children.add(const TextSpan(text: '\n'));
      for (final run in lines[i]) {
        children.add(
          TextSpan(
            text: run.text,
            style: TextStyle(
              fontWeight: run.bold ? FontWeight.w700 : null,
              color: run.color,
              fontSize: run.size,
            ),
          ),
        );
      }
    }
    return TextSpan(style: base, children: children);
  }
}
