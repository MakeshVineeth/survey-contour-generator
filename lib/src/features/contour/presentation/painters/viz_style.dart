import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../../core/theme/app_colors.dart';

/// Text styles and small helpers shared by the map, chart and TIN painters.
abstract final class VizStyle {
  /// Outfit UI text.
  static TextStyle sans(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => TextStyle(
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    decoration: TextDecoration.none,
  );

  /// JetBrains Mono (numbers, coordinates, map labels).
  static TextStyle mono(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => TextStyle(
    fontFamily: AppFonts.mono,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    decoration: TextDecoration.none,
  );

  /// Lays out a single-line label. Caller owns (and disposes) the painter.
  static TextPainter label(
    String text,
    TextStyle style, {
    TextAlign align = TextAlign.left,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    if (maxWidth == null) {
      tp.layout();
    } else {
      tp.layout(maxWidth: maxWidth);
    }
    return tp;
  }

  /// Paints [text] once and releases the painter.
  static void drawText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    TextAlign align = TextAlign.left,
  }) {
    final tp = label(text, style, align: align);
    final dx = switch (align) {
      TextAlign.center => -tp.width / 2,
      TextAlign.right || TextAlign.end => -tp.width,
      _ => 0.0,
    };
    tp.paint(canvas, at + Offset(dx, 0));
    tp.dispose();
  }
}

/// Builds the outline of a polyline with the dash pattern `[on, off]`
/// (canvas `setLineDash`); the pattern runs continuously along the line.
Path dashedPolyline(List<Offset> pts, double on, double off) {
  final path = Path();
  if (pts.length < 2) return path;
  final period = on + off;
  var phase = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1];
    final b = pts[i];
    final len = (b - a).distance;
    if (len == 0) continue;
    final dir = (b - a) / len;
    var pos = 0.0;
    while (pos < len) {
      final inDash = phase < on;
      final remainInState = inDash ? on - phase : period - phase;
      final step = math.min(remainInState, len - pos);
      if (inDash) {
        path
          ..moveTo(a.dx + dir.dx * pos, a.dy + dir.dy * pos)
          ..lineTo(a.dx + dir.dx * (pos + step), a.dy + dir.dy * (pos + step));
      }
      pos += step;
      phase = (phase + step) % period;
    }
  }
  return path;
}
