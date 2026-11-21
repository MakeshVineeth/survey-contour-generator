import 'geometry.dart';

/// One facet of the triangulated irregular network.
final class Triangle {
  const Triangle(this.p1, this.p2, this.p3);

  final SurveyPoint p1;
  final SurveyPoint p2;
  final SurveyPoint p3;
}
