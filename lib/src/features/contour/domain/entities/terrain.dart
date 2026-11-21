/// Triangle counts per slope class.
final class SlopeDistribution {
  const SlopeDistribution({
    required this.flat,
    required this.gentle,
    required this.moderate,
    required this.steep,
    required this.extreme,
  });

  final int flat;
  final int gentle;
  final int moderate;
  final int steep;
  final int extreme;
}

/// Overall terrain classification, ordered from flattest to steepest.
enum TerrainType { flat, gentle, moderate, steep, extreme }

/// Elevation statistics of the survey points.
final class ElevationStats {
  const ElevationStats({
    required this.min,
    required this.max,
    required this.avg,
  });

  final double min;
  final double max;
  final double avg;

  double get range => max - min;
}

/// Slope statistics in degrees.
final class SlopeStats {
  const SlopeStats({required this.avgDeg, required this.maxDeg});

  final double avgDeg;
  final double maxDeg;
}

/// Engineering statistics derived from the TIN.
final class TerrainStats {
  const TerrainStats({
    required this.area,
    required this.pointCount,
    required this.triangleCount,
    required this.elevation,
    required this.slope,
    required this.slopeDistribution,
    required this.terrainType,
  });

  final double area;
  final int pointCount;
  final int triangleCount;
  final ElevationStats elevation;
  final SlopeStats slope;
  final SlopeDistribution slopeDistribution;
  final TerrainType terrainType;
}

/// Rule-based narrative summary of a terrain.
final class TerrainSummary {
  const TerrainSummary({
    required this.paragraphs,
    required this.recommendations,
    required this.suitability,
    required this.slopeRisk,
  });

  /// The five summary paragraphs, in display order.
  final List<String> paragraphs;
  final List<String> recommendations;
  final String suitability;
  final String slopeRisk;
}
