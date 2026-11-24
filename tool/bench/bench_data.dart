import 'dart:math' as math;

import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';

/// Deterministic synthetic survey: jittered grid over rolling terrain.
List<SurveyPoint> generateSurvey(int n, {int seed = 42}) {
  final rnd = math.Random(seed);
  final side = math.sqrt(n).ceil();
  final out = <SurveyPoint>[];
  for (var i = 0; i < n; i++) {
    final gx = i % side, gy = i ~/ side;
    final x = 500000 + gx * 10 + rnd.nextDouble() * 6;
    final y = 4000000 + gy * 10 + rnd.nextDouble() * 6;
    final z = 100 +
        20 * math.sin(gx / 7) * math.cos(gy / 9) +
        gx * 0.05 +
        rnd.nextDouble();
    out.add(SurveyPoint(
      borehole: 'BH${i + 1}',
      x: double.parse(x.toStringAsFixed(3)),
      y: double.parse(y.toStringAsFixed(3)),
      z: double.parse(z.toStringAsFixed(3)),
    ));
  }
  return out;
}
