import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/contour_label_anchor.dart';

SurveyPoint _pt(double x, double y) =>
    SurveyPoint(borehole: 'P', x: x, y: y, z: 0);

void main() {
  // A straight contour along y = 0 with a vertex every 10 units.
  final line = [for (var i = 0; i <= 10; i++) Point2(i * 10.0, 0)];

  test('keeps the middle vertex when it is clear of every point', () {
    final survey = [_pt(0, 80), _pt(100, 80)];
    final c = ContourLabelAnchor.clearanceFor(survey);
    expect(ContourLabelAnchor.indexFor(line, survey, c), 5);
  });

  test('slides off a survey point sitting on the middle vertex', () {
    final survey = [_pt(50, 1), _pt(0, 80), _pt(100, 80)];
    final c = ContourLabelAnchor.clearanceFor(survey);
    final i = ContourLabelAnchor.indexFor(line, survey, c);
    expect(i, isNot(5));
    final p = line[i];
    final d = (p.x - 50).abs();
    expect(d, greaterThanOrEqualTo(c));
  });

  test('falls back to the middle when every vertex is crowded', () {
    final survey = [for (var i = 0; i <= 10; i++) _pt(i * 10.0, 0)];
    final c = ContourLabelAnchor.clearanceFor(survey);
    expect(ContourLabelAnchor.indexFor(line, survey, c), 5);
  });

  test('no survey points means no clearance requirement', () {
    expect(ContourLabelAnchor.clearanceFor(const []), 0);
    expect(ContourLabelAnchor.indexFor(line, const [], 0), 5);
  });
}
