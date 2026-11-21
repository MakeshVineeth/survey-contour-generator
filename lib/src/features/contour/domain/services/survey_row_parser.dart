import '../entities/geometry.dart';
import '../entities/survey_import.dart';

/// One spreadsheet row keyed by its header text.
typedef SurveyRow = Map<String, Object?>;

/// Converts spreadsheet sheets into survey points and breaklines.
///
/// Mirrors the original import (same column aliases and precedence). Unlike
/// the JavaScript, a value of `0` counts as present.
final class SurveyRowParser {
  const SurveyRowParser._();

  static const int maxNameLength = 64;

  /// Import limits: the triangulation is O(n^2), so larger inputs would freeze
  /// the app. Rows beyond the limits are dropped ([SurveyImportResult.truncated]).
  static const int maxPoints = 20000;
  static const int maxBreakLinePoints = 50000;

  /// Coordinates beyond this magnitude are treated as invalid (they overflow
  /// the triangulation's circumcircle arithmetic).
  static const double maxCoordinate = 1e9;

  static const List<String> _boreholeKeys = [
    'BoreholeID', 'BH', 'ID', 'Name', 'Point', 'Borehole', //
  ];
  static const List<String> _xKeys = ['X', 'Easting', 'E'];
  static const List<String> _yKeys = ['Y', 'Northing', 'N'];
  static const List<String> _zKeys = ['RL', 'Z', 'Elevation', 'Elev'];
  static const List<String> _lineKeys = ['LineName', 'BreakLine', 'Line'];

  static final RegExp _floatPrefix = RegExp(
    r'^[+-]?(?:Infinity|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)',
  );

  /// Parses every sheet; breaklines are grouped per sheet by name (first-seen
  /// order) and kept only with at least two points.
  static SurveyImportResult parse(List<List<SurveyRow>> sheets) {
    final points = <SurveyPoint>[];
    final breakLines = <BreakLine>[];
    final counter = _LineCounter();
    var truncated = false;
    for (final rows in sheets) {
      final lines = <String, List<Point3>>{};
      for (final row in rows) {
        truncated |= _parseRow(row, points, lines, counter);
      }
      lines.forEach((name, pts) {
        if (pts.length >= 2) {
          breakLines.add(BreakLine(name: name, points: pts));
        }
      });
    }
    return SurveyImportResult(
      points: points,
      breakLines: breakLines,
      truncated: truncated,
    );
  }

  /// Returns true when the row was dropped because of an import limit.
  static bool _parseRow(
    SurveyRow row,
    List<SurveyPoint> points,
    Map<String, List<Point3>> lines,
    _LineCounter counter,
  ) {
    final x = parseFloatJs(_firstPresent(row, _xKeys));
    final y = parseFloatJs(_firstPresent(row, _yKeys));
    final z = parseFloatJs(_firstPresent(row, _zKeys));
    if (!_validCoordinate(x) || !_validCoordinate(y) || !_validCoordinate(z)) {
      return false;
    }

    final lineName = _name(_firstPresent(row, _lineKeys));
    if (lineName != null) {
      if (counter.count >= maxBreakLinePoints) return true;
      counter.count++;
      (lines[lineName] ??= []).add(Point3(x, y, z));
      return false;
    }
    final borehole = _name(_firstPresent(row, _boreholeKeys));
    if (borehole == null) return false;
    if (points.length >= maxPoints) return true;
    points.add(SurveyPoint(borehole: borehole, x: x, y: y, z: z));
    return false;
  }

  static bool _validCoordinate(double v) =>
      v.isFinite && v.abs() <= maxCoordinate;

  /// First alias whose value is neither null nor an empty string (0 is kept).
  static Object? _firstPresent(SurveyRow row, List<String> keys) {
    for (final key in keys) {
      final v = row[key];
      if (v == null) continue;
      if (v is String && v.isEmpty) continue;
      if (v is num && v.isNaN) continue;
      return v;
    }
    return null;
  }

  static String? _name(Object? value) {
    if (value == null) return null;
    final text = _display(value).trim();
    if (text.isEmpty) return null;
    return text.length > maxNameLength
        ? text.substring(0, maxNameLength)
        : text;
  }

  static String _display(Object value) {
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// JavaScript `parseFloat` for a cell value: numbers pass through, strings
  /// use their longest numeric prefix, anything else is NaN.
  static double parseFloatJs(Object? value) {
    if (value is num) return value.toDouble();
    if (value is! String) return double.nan;
    final match = _floatPrefix.firstMatch(value.trimLeft());
    if (match == null) return double.nan;
    final token = match.group(0)!;
    if (token.endsWith('Infinity')) {
      return token.startsWith('-') ? double.negativeInfinity : double.infinity;
    }
    return double.tryParse(token) ?? double.nan;
  }
}

class _LineCounter {
  int count = 0;
}
