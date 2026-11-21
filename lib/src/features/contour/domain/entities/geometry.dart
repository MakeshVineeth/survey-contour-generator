/// A 2D location on the survey plane (easting, northing).
final class Point2 {
  const Point2(this.x, this.y);

  final double x;
  final double y;
}

/// A surveyed 3D location without an identifier (used by breaklines).
final class Point3 {
  const Point3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// A named survey point: easting [x], northing [y] and reduced level [z].
///
/// Identity matters: two points with equal coordinates are distinct vertices
/// in the triangulation, exactly like in the original application.
final class SurveyPoint {
  const SurveyPoint({
    required this.borehole,
    required this.x,
    required this.y,
    required this.z,
  });

  final String borehole;
  final double x;
  final double y;
  final double z;
}

/// A hard breakline: a named polyline of 3D points.
final class BreakLine {
  const BreakLine({required this.name, required this.points});

  final String name;
  final List<Point3> points;
}
