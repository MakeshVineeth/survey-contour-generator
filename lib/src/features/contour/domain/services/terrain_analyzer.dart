import 'dart:math' as math;

import '../../../../core/utils/js_number.dart';

import '../entities/contour.dart';
import '../entities/geometry.dart';
import '../entities/terrain.dart';
import '../entities/triangle.dart';

/// Computes terrain statistics and the rule-based engineering summary.
final class TerrainAnalyzer {
  const TerrainAnalyzer._();

  static const double _radToDeg = 180 / math.pi;

  /// Statistics for [points] and their [triangles]; null without points.
  static TerrainStats? analyze(List<SurveyPoint> points, List<Triangle> triangles) {
    if (points.isEmpty) return null;

    var minZ = double.infinity, maxZ = double.negativeInfinity, sumZ = 0.0;
    for (final p in points) {
      minZ = math.min(minZ, p.z);
      maxZ = math.max(maxZ, p.z);
      sumZ += p.z;
    }

    var totalArea = 0.0, slopeSum = 0.0, maxSlope = 0.0;
    final counts = List<int>.filled(5, 0);
    for (final tri in triangles) {
      totalArea += _area(tri);
      final slope = _slope(tri);
      slopeSum += slope;
      maxSlope = math.max(maxSlope, slope);
      counts[_slopeClass(math.atan(slope) * _radToDeg)]++;
    }

    final avgSlope = triangles.isEmpty ? 0.0 : slopeSum / triangles.length;
    final avgSlopeDeg = math.atan(avgSlope) * _radToDeg;
    return TerrainStats(
      area: totalArea,
      pointCount: points.length,
      triangleCount: triangles.length,
      elevation: ElevationStats(min: minZ, max: maxZ, avg: sumZ / points.length),
      slope: SlopeStats(
        avgDeg: avgSlopeDeg,
        maxDeg: math.atan(maxSlope) * _radToDeg,
      ),
      slopeDistribution: SlopeDistribution(
        flat: counts[0],
        gentle: counts[1],
        moderate: counts[2],
        steep: counts[3],
        extreme: counts[4],
      ),
      terrainType: _terrainType(avgSlopeDeg),
    );
  }

  static double _area(Triangle t) =>
      ((t.p1.x * (t.p2.y - t.p3.y) +
                  t.p2.x * (t.p3.y - t.p1.y) +
                  t.p3.x * (t.p1.y - t.p2.y)) /
              2)
          .abs();

  /// Steepest of the two edges leaving the first vertex (rise over run).
  static double _slope(Triangle t) {
    final dist1 = math.sqrt(_sq(t.p2.x - t.p1.x) + _sq(t.p2.y - t.p1.y));
    final dist2 = math.sqrt(_sq(t.p3.x - t.p1.x) + _sq(t.p3.y - t.p1.y));
    final s1 = dist1 > 0 ? ((t.p2.z - t.p1.z) / dist1).abs() : 0.0;
    final s2 = dist2 > 0 ? ((t.p3.z - t.p1.z) / dist2).abs() : 0.0;
    return math.max(s1, s2);
  }

  static double _sq(double v) => v * v;

  static int _slopeClass(double deg) {
    if (deg < 5) return 0;
    if (deg < 15) return 1;
    if (deg < 30) return 2;
    if (deg < 45) return 3;
    return 4;
  }

  static TerrainType _terrainType(double avgDeg) {
    if (avgDeg > 15) return TerrainType.extreme;
    if (avgDeg > 10) return TerrainType.steep;
    if (avgDeg > 5) return TerrainType.moderate;
    if (avgDeg > 2) return TerrainType.gentle;
    return TerrainType.flat;
  }

  /// Builds the narrative summary; null when [stats] is null.
  static TerrainSummary? summarize(
    TerrainStats? stats,
    List<BreakLine> breakLines,
    List<Contour> contours,
  ) {
    if (stats == null) return null;

    final area = stats.area;
    final safeArea = (area == 0 || area.isNaN) ? 1.0 : area;
    final elevation = stats.elevation;
    final range = elevation.range;
    final dist = stats.slopeDistribution;

    final density = stats.pointCount / safeArea * 10000;
    final reliefRatio = range / math.sqrt(safeArea);
    final steepPercent = stats.triangleCount == 0
        ? 0.0
        : (dist.steep + dist.extreme) / stats.triangleCount * 100;

    final recommendations = <String>[];
    final slopeRisk = _slopeRisk(steepPercent, recommendations);
    final suitability = _suitability(stats.terrainType, range, recommendations);

    final contourDensity = contours.length / (range == 0 ? 1 : range);
    final contourNote = contourDensity > 5
        ? 'Dense contour coverage enables detailed grading design.'
        : contourDensity > 2
            ? 'Adequate contour definition for planning purposes.'
            : 'Consider finer contour interval for detailed design work.';
    final breaklineNote = breakLines.isEmpty
        ? ''
        : '${breakLines.length} breakline(s) incorporated to accurately model terrain discontinuities.';

    final type = stats.terrainType.name;
    final para1 = 'This $type terrain survey encompasses ${area.toFixed(0)} m² '
        'with ${stats.pointCount} survey points representing ${_densityText(density)}. '
        'The triangulated surface model comprises ${stats.triangleCount} facets, '
        'providing ${_reliefText(reliefRatio)} across the study area.';
    final para2 = 'Elevation analysis reveals a ${range.toFixed(2)}m vertical range '
        'from ${elevation.min.toFixed(2)}m to ${elevation.max.toFixed(2)}m '
        '(mean: ${elevation.avg.toFixed(2)}m). The average terrain slope of '
        '${stats.slope.avgDeg.toFixed(1)}° with maximum gradients reaching '
        '${stats.slope.maxDeg.toFixed(1)}° indicates the site is $suitability.';
    final para3 = 'Slope distribution analysis: ${dist.flat} flat, ${dist.gentle} gentle, '
        '${dist.moderate} moderate, ${dist.steep} steep, and ${dist.extreme} extreme '
        'zones identified. $slopeRisk.';
    final para4 = '$contourNote $breaklineNote'.trim();
    final para5 = recommendations.isNotEmpty
        ? 'Recommendations: ${recommendations.join('; ')}.'
        : 'No specific concerns identified - site conditions favorable for development.';

    return TerrainSummary(
      paragraphs: [para1, para2, para3, para4, para5],
      recommendations: recommendations,
      suitability: suitability,
      slopeRisk: slopeRisk,
    );
  }

  static String _densityText(double density) {
    if (density > 10) return 'high-density survey with excellent spatial resolution';
    if (density > 5) return 'well-distributed survey points providing good coverage';
    if (density > 2) return 'moderate point density suitable for general mapping';
    return 'sparse survey coverage - consider additional data points for critical areas';
  }

  static String _reliefText(double ratio) {
    if (ratio > 0.1) return 'significant vertical relief relative to survey extent';
    if (ratio > 0.05) return 'moderate topographic variation';
    return 'relatively uniform elevation profile';
  }

  static String _slopeRisk(double steepPercent, List<String> recommendations) {
    if (steepPercent > 30) {
      recommendations
        ..add('geotechnical assessment recommended')
        ..add('erosion control measures advised');
      return 'High erosion and stability risk identified';
    }
    if (steepPercent > 15) {
      recommendations.add('drainage planning recommended');
      return 'Moderate slope concerns in localized areas';
    }
    if (steepPercent > 5) {
      recommendations.add('standard grading practices sufficient');
      return 'Minor steep zones detected';
    }
    recommendations.add('minimal earthwork expected');
    return 'Favorable slope conditions throughout';
  }

  static String _suitability(
    TerrainType type,
    double range,
    List<String> recommendations,
  ) {
    if (type == TerrainType.flat || type == TerrainType.gentle) {
      if (range < 2) recommendations.add('verify drainage gradient adequacy');
      return 'excellent for most construction activities';
    }
    if (type == TerrainType.moderate) {
      recommendations.add('cut-fill balancing analysis recommended');
      return 'suitable with standard site preparation';
    }
    recommendations
      ..add('retaining structures may be required')
      ..add('phased development approach suggested');
    return 'challenging terrain requiring specialized engineering';
  }
}
