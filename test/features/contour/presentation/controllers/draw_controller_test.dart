import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/triangle.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/draw_elevation.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/contour_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/display_settings_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/draw_controller.dart';

import '../../../../helpers/fakes.dart';

void main() {
  late ContourController contours;
  late DrawController draw;

  setUp(() {
    contours = ContourController(
      files: FakeFileService(),
      printer: FakePrintService(),
      runner: FakeComputeRunner(),
    );
    draw = DrawController(contours);
  });
  tearDown(() => contours.dispose());

  test('toggle on, add points, toggle off commits a breakline', () {
    draw.toggleDrawMode();
    expect(draw.drawMode, isTrue);
    draw.addPoint(const Point3(0, 0, 1));
    expect(contours.toast, '📍 Point added: RL 1.00m (extrapolated)');
    draw.addPoint(const Point3(1, 1, 2));
    draw.toggleDrawMode();
    expect(draw.drawMode, isFalse);
    expect(draw.currentBreakline, isEmpty);
    expect(contours.breakLines.single.name, 'BL-1');
    expect(contours.breakLines.single.points.length, 2);
    expect(contours.toast, '✓ Breakline added');
  });

  test('toggle off with fewer than 2 points discards', () {
    draw.toggleDrawMode();
    draw.addPoint(const Point3(0, 0, 1));
    draw.toggleDrawMode();
    expect(contours.breakLines, isEmpty);
    expect(draw.currentBreakline, isEmpty);
  });

  test('undo and cancel', () {
    draw.toggleDrawMode();
    draw.addPoint(const Point3(0, 0, 1));
    draw.addPoint(const Point3(1, 1, 1));
    draw.undoLastPoint();
    expect(draw.currentBreakline.length, 1);
    draw.undoLastPoint();
    draw.undoLastPoint();
    expect(draw.currentBreakline, isEmpty);
    draw.addPoint(const Point3(0, 0, 1));
    draw.setMobileDrawMode(MobileDrawMode.navigate);
    draw.cancelDraw();
    expect(draw.drawMode, isFalse);
    expect(draw.currentBreakline, isEmpty);
    expect(draw.mobileDrawMode, MobileDrawMode.add);
  });

  test('toggling resets mobile mode and rejects non-finite points', () {
    draw.toggleDrawMode();
    draw.setMobileDrawMode(MobileDrawMode.navigate);
    draw.addPoint(const Point3(double.nan, 0, 0));
    expect(draw.currentBreakline, isEmpty);
    draw.toggleDrawMode();
    expect(draw.mobileDrawMode, MobileDrawMode.add);
  });

  test('addPointAt interpolates inside the TIN', () async {
    contours.loadSample();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    draw.toggleDrawMode();
    draw.addPointAt(150, 120);
    expect(draw.currentBreakline.single.z, closeTo(97.2, 1e-6));
  });

  test('onDataReset can cancel drawing and reset display settings', () {
    final display = DisplaySettingsController()..showAllBoreholes = true;
    contours.onDataReset = () {
      draw.cancelDraw();
      display.showAllBoreholes = false;
    };
    draw.toggleDrawMode();
    contours.clear();
    expect(draw.drawMode, isFalse);
    expect(display.showAllBoreholes, isFalse);
  });

  group('DrawElevation', () {
    const a = SurveyPoint(borehole: 'a', x: 0, y: 0, z: 0);
    const b = SurveyPoint(borehole: 'b', x: 10, y: 0, z: 10);
    const cc = SurveyPoint(borehole: 'c', x: 0, y: 10, z: 20);

    test('barycentric inside', () {
      final z = DrawElevation.estimate(
        x: 2,
        y: 3,
        points: const [a, b, cc],
        triangles: const [Triangle(a, b, cc)],
      );
      expect(z, closeTo(0.2 * 10 + 0.3 * 20, 1e-9));
    });

    test('outside extrapolates and clamps to survey range plus margin', () {
      final z = DrawElevation.estimate(
        x: 1000,
        y: 1000,
        points: const [a, b, cc],
        triangles: const [Triangle(a, b, cc)],
      );
      expect(z, lessThanOrEqualTo(20 + 4));
      expect(z, greaterThanOrEqualTo(0 - 4));
    });

    test('no points gives 0; flat survey margin is 1', () {
      expect(
        DrawElevation.estimate(
          x: 1,
          y: 1,
          points: const [],
          triangles: const [],
        ),
        0,
      );
      const p1 = SurveyPoint(borehole: 'p', x: 0, y: 0, z: 5);
      const p2 = SurveyPoint(borehole: 'q', x: 10, y: 0, z: 5);
      final z = DrawElevation.estimate(
        x: 50,
        y: 0,
        points: const [p1, p2],
        triangles: const [],
      );
      expect(z, 5);
    });
  });

  test('display settings defaults and notifications', () {
    final d = DisplaySettingsController();
    expect([
      d.showTIN,
      d.showContours,
      d.showBreakLines,
      d.showLabels,
    ], everyElement(isTrue));
    expect(d.showAllBoreholes, isFalse);
    var n = 0;
    d.addListener(() => n++);
    d.showTIN = false;
    d.showTIN = false;
    d.showAllBoreholes = true;
    expect(n, 2);
    expect(d.showTIN, isFalse);
  });
}
