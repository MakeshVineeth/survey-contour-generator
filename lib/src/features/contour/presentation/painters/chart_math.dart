import 'dart:ui';

import 'dart:math' as math;

/// Axis range and tick values of a chart axis.
final class AxisScale {
  const AxisScale({required this.min, required this.max, required this.ticks});

  final double min;
  final double max;
  final List<double> ticks;

  double get span => max - min == 0 ? 1 : max - min;
}

/// Highcharts-like "nice" axis computation and spline geometry.
abstract final class ChartMath {
  static const List<double> _multiples = [1, 2, 2.5, 5, 10];

  /// Normalises a raw tick interval to 1, 2, 2.5, 5 or 10 times a power of ten.
  static double niceInterval(double raw) {
    if (!raw.isFinite || raw <= 0) return 1;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floorToDouble());
    final normalized = raw / magnitude;
    var chosen = _multiples.last;
    for (var i = 0; i < _multiples.length - 1; i++) {
      if (normalized <= (_multiples[i] + _multiples[i + 1]) / 2) {
        chosen = _multiples[i];
        break;
      }
    }
    return chosen * magnitude;
  }

  /// Value axis for data in [dataMin]..[dataMax] over [pixels] of length.
  ///
  /// With [explicitMin]/[explicitMax] the range is kept as given (ticks fall
  /// inside it); otherwise both ends are extended to tick positions.
  static AxisScale valueAxis(
    double dataMin,
    double dataMax,
    double pixels, {
    double tickPixelInterval = 72,
    double? explicitMin,
    double? explicitMax,
  }) {
    var lo = explicitMin ?? dataMin;
    var hi = explicitMax ?? dataMax;
    if (hi - lo == 0) {
      lo -= 1;
      hi += 1;
    }
    final count = math.max(1, pixels / tickPixelInterval);
    final interval = niceInterval((hi - lo) / count);
    if (explicitMin == null) lo = (lo / interval).floorToDouble() * interval;
    if (explicitMax == null) hi = (hi / interval).ceilToDouble() * interval;
    final ticks = <double>[];
    var t = (lo / interval).ceilToDouble() * interval;
    for (var i = 0; t <= hi + interval * 1e-9 && i < 200; i++) {
      ticks.add(_clean(t, interval));
      t += interval;
    }
    return AxisScale(min: lo, max: hi, ticks: ticks);
  }

  /// Integer-index axis `0..lastIndex` with ticks every [interval] (or a nice
  /// automatic interval when null).
  static AxisScale indexAxis(int lastIndex, double pixels, {int? interval}) {
    final step =
        (interval ?? niceInterval(lastIndex * 100 / math.max(1, pixels)))
            .toDouble();
    final ticks = <double>[];
    for (var t = 0.0; t <= lastIndex + 1e-9 && ticks.length < 200; t += step) {
      ticks.add(t);
    }
    return AxisScale(
      min: 0,
      max: lastIndex <= 0 ? 1 : lastIndex.toDouble(),
      ticks: ticks,
    );
  }

  static double _clean(double v, double interval) {
    final digits = math.max(0, -(math.log(interval) / math.ln10).floor() + 1);
    return double.parse(v.toStringAsFixed(math.min(digits, 10)));
  }

  /// Highcharts `spline` path through [pts] (smoothing 1.5, no overshoot).
  static Path spline(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts[0].dx, pts[0].dy);
    final ctrl = _controlPoints(pts);
    for (var i = 1; i < pts.length; i++) {
      final prev = ctrl[i - 1];
      final cur = ctrl[i];
      path.cubicTo(
        prev.right.dx,
        prev.right.dy,
        cur.left.dx,
        cur.left.dy,
        pts[i].dx,
        pts[i].dy,
      );
    }
    return path;
  }

  static List<({Offset left, Offset right})> _controlPoints(List<Offset> pts) {
    return [
      for (var i = 0; i < pts.length; i++)
        if (i == 0 || i == pts.length - 1)
          (left: pts[i], right: pts[i])
        else
          _controlAt(pts[i - 1], pts[i], pts[i + 1]),
    ];
  }

  static ({Offset left, Offset right}) _controlAt(
    Offset a,
    Offset p,
    Offset n,
  ) {
    const smoothing = 1.5;
    const denom = smoothing + 1;
    final lx = (smoothing * p.dx + a.dx) / denom;
    var ly = (smoothing * p.dy + a.dy) / denom;
    final rx = (smoothing * p.dx + n.dx) / denom;
    var ry = (smoothing * p.dy + n.dy) / denom;
    if (rx != lx) {
      final correction = ((ry - ly) * (rx - p.dx)) / (rx - lx) + p.dy - ry;
      ly += correction;
      ry += correction;
    }
    if (ly > a.dy && ly > p.dy) {
      ly = math.max(a.dy, p.dy);
      ry = 2 * p.dy - ly;
    } else if (ly < a.dy && ly < p.dy) {
      ly = math.min(a.dy, p.dy);
      ry = 2 * p.dy - ly;
    }
    if (ry > n.dy && ry > p.dy) {
      ry = math.max(n.dy, p.dy);
      ly = 2 * p.dy - ry;
    } else if (ry < n.dy && ry < p.dy) {
      ry = math.min(n.dy, p.dy);
      ly = 2 * p.dy - ry;
    }
    return (left: Offset(lx, ly), right: Offset(rx, ry));
  }

  /// Formats [v] like Highcharts `{value:.Nf}`.
  static String fixed(double v, int digits) =>
      (v == 0 ? 0.0 : v).toStringAsFixed(digits);
}
