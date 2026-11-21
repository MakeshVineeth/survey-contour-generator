import 'geometry.dart';

/// Points and breaklines read from a spreadsheet workbook.
final class SurveyImportResult {
  const SurveyImportResult({
    required this.points,
    required this.breakLines,
    this.truncated = false,
  });

  static const SurveyImportResult empty = SurveyImportResult(
    points: [],
    breakLines: [],
  );

  final List<SurveyPoint> points;
  final List<BreakLine> breakLines;

  /// True when rows were dropped because an import limit was reached.
  final bool truncated;

  bool get isEmpty => points.isEmpty && breakLines.isEmpty;
}
