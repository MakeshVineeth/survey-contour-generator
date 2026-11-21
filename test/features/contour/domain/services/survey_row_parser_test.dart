import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/survey_row_parser.dart';

SurveyRow r(Map<String, Object?> m) => m;

void main() {
  group('parseFloatJs', () {
    test('numbers and numeric prefixes', () {
      expect(SurveyRowParser.parseFloatJs(12.5), 12.5);
      expect(SurveyRowParser.parseFloatJs(3), 3.0);
      expect(SurveyRowParser.parseFloatJs('12.5m'), 12.5);
      expect(SurveyRowParser.parseFloatJs('  -4e2x'), -400);
      expect(SurveyRowParser.parseFloatJs('.5'), 0.5);
      expect(SurveyRowParser.parseFloatJs('5.'), 5);
      expect(SurveyRowParser.parseFloatJs('0'), 0);
    });

    test('non numeric is NaN', () {
      expect(SurveyRowParser.parseFloatJs('abc').isNaN, isTrue);
      expect(SurveyRowParser.parseFloatJs('').isNaN, isTrue);
      expect(SurveyRowParser.parseFloatJs(true).isNaN, isTrue);
      expect(SurveyRowParser.parseFloatJs(null).isNaN, isTrue);
    });
  });

  group('parse', () {
    test('reads points using every alias', () {
      final res = SurveyRowParser.parse([
        [
          r({'BoreholeID': 'A', 'X': 1, 'Y': 2, 'RL': 3}),
          r({'BH': 'B', 'Easting': 4, 'Northing': 5, 'Z': 6}),
          r({'ID': 'C', 'E': 7, 'N': 8, 'Elevation': 9}),
          r({'Name': 'D', 'X': 1, 'Y': 1, 'Elev': 2}),
          r({'Point': 'E', 'X': 1, 'Y': 1, 'RL': 2}),
          r({'Borehole': 'F', 'X': 1, 'Y': 1, 'RL': 2}),
        ],
      ]);
      expect(res.points.map((p) => p.borehole), ['A', 'B', 'C', 'D', 'E', 'F']);
      expect(res.points[1].x, 4);
      expect(res.points[2].z, 9);
    });

    test('alias precedence', () {
      final res = SurveyRowParser.parse([
        [
          r({
            'BoreholeID': 'first',
            'BH': 'second',
            'X': 1,
            'Easting': 9,
            'Y': 2,
            'Northing': 9,
            'RL': 3,
            'Z': 9,
          }),
        ],
      ]);
      final p = res.points.single;
      expect((p.borehole, p.x, p.y, p.z), ('first', 1.0, 2.0, 3.0));
    });

    test('zero is kept and empty falls through', () {
      final res = SurveyRowParser.parse([
        [
          r({'BH': 'A', 'X': 0, 'Easting': 5, 'Y': '0', 'RL': 0, 'Z': 7}),
          r({'BH': 'B', 'X': '', 'Easting': 5, 'Y': 1, 'RL': 1}),
          r({'BH': 0, 'X': 1, 'Y': 1, 'RL': 1}),
        ],
      ]);
      expect(res.points.length, 3);
      expect(res.points[0].x, 0);
      expect(res.points[0].y, 0);
      expect(res.points[0].z, 0);
      expect(res.points[1].x, 5);
      expect(res.points[2].borehole, '0');
    });

    test('skips malformed rows', () {
      final res = SurveyRowParser.parse([
        [
          r({'BH': 'A', 'X': 'n/a', 'Y': 1, 'RL': 1}),
          r({'BH': 'B', 'X': 1, 'Y': 1}),
          r({'X': 1, 'Y': 1, 'RL': 1}),
          r({'BH': 'C', 'X': double.infinity, 'Y': 1, 'RL': 1}),
          r({'BH': 'D', 'X': double.nan, 'Y': 1, 'RL': 1}),
          r({'BH': 'OK', 'X': '12.5m', 'Y': ' 3', 'RL': '4x'}),
        ],
      ]);
      expect(res.points.length, 1);
      expect(res.points.single.x, 12.5);
      expect(res.points.single.z, 4);
    });

    test('groups breaklines per sheet, drops < 2 points, first-seen order', () {
      final res = SurveyRowParser.parse([
        [
          r({'LineName': 'B', 'X': 0, 'Y': 0, 'RL': 1}),
          r({'LineName': 'A', 'X': 1, 'Y': 0, 'RL': 1}),
          r({'LineName': 'B', 'X': 1, 'Y': 1, 'RL': 2}),
          r({'BreakLine': 'Solo', 'X': 5, 'Y': 5, 'RL': 5}),
          r({'Line': 'A', 'X': 2, 'Y': 2, 'RL': 3, 'BH': 'ignored'}),
        ],
        [
          r({'LineName': 'B', 'X': 9, 'Y': 9, 'RL': 9}),
        ],
      ]);
      expect(res.points, isEmpty);
      expect(res.breakLines.map((b) => b.name), ['B', 'A']);
      expect(res.breakLines[0].points.length, 2);
    });

    test('same breakline name in two sheets stays separate', () {
      final line = [
        r({'LineName': 'L', 'X': 0, 'Y': 0, 'RL': 1}),
        r({'LineName': 'L', 'X': 1, 'Y': 1, 'RL': 1}),
      ];
      final res = SurveyRowParser.parse([line, line]);
      expect(res.breakLines.length, 2);
    });

    test('clamps and trims names', () {
      final res = SurveyRowParser.parse([
        [
          r({'BH': '  ${'x' * 100}  ', 'X': 1, 'Y': 1, 'RL': 1}),
          r({'BH': '   ', 'X': 1, 'Y': 1, 'RL': 1}),
          r({'BH': 12.0, 'X': 1, 'Y': 1, 'RL': 1}),
        ],
      ]);
      expect(res.points.length, 2);
      expect(res.points[0].borehole, 'x' * 64);
      expect(res.points[1].borehole, '12');
    });

    test('drops huge coordinates and Infinity', () {
      final res = SurveyRowParser.parse([
        [
          r({'BH': 'a', 'X': 1e12, 'Y': 1, 'RL': 1}),
          r({'BH': 'b', 'X': 'Infinity', 'Y': 1, 'RL': 1}),
          r({'BH': 'c', 'X': 1e9, 'Y': -1e9, 'RL': 0}),
        ],
      ]);
      expect(res.points.map((p) => p.borehole), ['c']);
      expect(res.truncated, isFalse);
    });

    test('caps the number of points and flags truncation', () {
      final rows = [
        for (var i = 0; i < SurveyRowParser.maxPoints + 5; i++)
          r({'BH': 'p$i', 'X': i, 'Y': i % 7, 'RL': 1}),
      ];
      final res = SurveyRowParser.parse([rows]);
      expect(res.points.length, SurveyRowParser.maxPoints);
      expect(res.truncated, isTrue);
    });

    test('empty input', () {
      expect(SurveyRowParser.parse(const []).isEmpty, isTrue);
    });
  });
}
