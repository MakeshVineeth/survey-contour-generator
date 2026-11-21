import 'dart:math' as math;

/// Number helpers that reproduce JavaScript semantics, so exported files stay
/// byte-identical to the original web application.
extension JsNumberFormat on double {
  /// Equivalent of JavaScript `Number.prototype.toFixed`.
  ///
  /// Negative zero prints as `0.000` (never `-0.000`), as in JavaScript.
  String toFixed(int fractionDigits) {
    final value = this == 0 ? 0.0 : this;
    return value.toStringAsFixed(fractionDigits);
  }
}

/// Equivalent of JavaScript `Math.round` (ties round towards +infinity).
double jsRound(double x) {
  final floor = x.floorToDouble();
  return x - floor >= 0.5 ? floor + 1 : floor;
}

/// Euclidean distance (`Math.hypot` for two components).
double hypot2(double dx, double dy) => math.sqrt(dx * dx + dy * dy);
