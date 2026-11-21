import 'geometry.dart';

/// A contour polyline at a given elevation [level].
final class Contour {
  const Contour({
    required this.level,
    required this.points,
    required this.isMajor,
  });

  final double level;
  final List<Point2> points;
  final bool isMajor;
}
