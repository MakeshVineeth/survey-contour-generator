import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/contour_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/map_view_controller.dart';

import '../../../../helpers/fakes.dart';

ContourController _newContours() => ContourController(
  files: FakeFileService(),
  printer: FakePrintService(),
  runner: FakeComputeRunner(),
);

void main() {
  late ContourController contours;
  late MapViewController view;

  setUp(() {
    contours = _newContours();
    view = MapViewController(contours);
  });

  tearDown(() {
    view.dispose();
    contours.dispose();
  });

  // Sample data spans x 75..275 and y 100..250.
  test('fits first loaded data once the viewport is known', () {
    contours.loadSample();
    view.setViewport(const Size(1000, 800));
    expect(view.centerX, 175);
    expect(view.centerY, 175);
    expect(view.scale, closeTo(4.2, 1e-9)); // (1000 - 160) / 200
  });

  test('fits when data arrives after the viewport', () {
    view.setViewport(const Size(1000, 800));
    expect(view.scale, 1);
    contours.loadSample();
    expect(view.scale, closeTo(4.2, 1e-9));
  });

  test('refits on resize, but not without data', () {
    view.setViewport(const Size(1000, 800));
    view.setViewport(const Size(500, 800));
    expect(view.scale, 1);
    contours.loadSample();
    view.setViewport(const Size(520, 800));
    expect(view.scale, closeTo(360 / 200, 1e-9));
  });

  test('a small height change (toolbar re-wrap) keeps zoom and pan', () {
    contours.loadSample();
    view.setViewport(const Size(400, 600));
    view.zoomAt(const Offset(100, 100), 2);
    view.beginPan();
    view.panTo(const Offset(30, -20));
    final scale = view.scale;
    final cx = view.centerX;
    final cy = view.centerY;
    view.setViewport(const Size(400, 560)); // toolbar grew by 40 px
    view.setViewport(const Size(400, 600));
    expect(view.scale, scale);
    expect(view.centerX, cx);
    expect(view.centerY, cy);
  });

  test('a large height change (rotation) refits', () {
    contours.loadSample();
    view.setViewport(const Size(400, 800));
    view.zoomAt(const Offset(100, 100), 2);
    view.setViewport(const Size(400, 400));
    expect(view.scale, closeTo(240 / 200, 1e-9)); // width-limited: 240 / 200
  });

  test('zoom about a point keeps the world point under the cursor', () {
    contours.loadSample();
    view.setViewport(const Size(1000, 800));
    const cursor = Offset(700, 200);
    final before = view.screenToWorld(cursor);
    view.zoomAt(cursor, 1.15);
    final after = view.screenToWorld(cursor);
    expect(view.scale, closeTo(4.2 * 1.15, 1e-9));
    expect(after.x, closeTo(before.x, 1e-9));
    expect(after.y, closeTo(before.y, 1e-9));
  });

  test('wheel direction and clamping', () {
    contours.loadSample();
    view.setViewport(const Size(1000, 800));
    final s = view.scale;
    view.wheelZoom(const Offset(500, 400), 100);
    expect(view.scale, closeTo(s * 0.85, 1e-9));
    view.wheelZoom(const Offset(500, 400), -100);
    expect(view.scale, closeTo(s * 0.85 * 1.15, 1e-9));
    view.zoomCentered(1e12);
    expect(view.scale, MapViewController.maxScale);
    view.zoomCentered(1e-30);
    expect(view.scale, MapViewController.minScale);
  });

  test('toolbar zoom keeps the centre', () {
    contours.loadSample();
    view.setViewport(const Size(1000, 800));
    final cx = view.centerX;
    view.zoomCentered(1.3);
    expect(view.centerX, cx);
    expect(view.scale, closeTo(4.2 * 1.3, 1e-9));
  });

  test('pan moves the centre opposite to the drag (Y flipped)', () {
    contours.loadSample();
    view.setViewport(const Size(1000, 800));
    view.beginPan();
    view.panTo(const Offset(42, -21));
    expect(view.centerX, closeTo(175 - 42 / 4.2, 1e-9));
    expect(view.centerY, closeTo(175 - 21 / 4.2, 1e-9));
    // The pan is relative to where it began.
    view.panTo(Offset.zero);
    expect(view.centerX, 175);
  });

  test('zoom is ignored without data, mouse coords need data', () {
    view.setViewport(const Size(1000, 800));
    view.zoomCentered(2);
    view.wheelZoom(const Offset(1, 1), 1);
    view.updateMouse(const Offset(500, 400));
    expect(view.scale, 1);
    expect(view.mouseCoords.value, isNull);
    contours.loadSample();
    view.updateMouse(const Offset(500, 400));
    final c = view.mouseCoords.value!;
    expect(c.x, closeTo(175, 1e-9));
    expect(c.y, closeTo(175, 1e-9));
  });

  test('data reset restores the default view and chains the old hook', () {
    var chained = 0;
    final other = _newContours()..onDataReset = () => chained++;
    final v = MapViewController(other)..setViewport(const Size(1000, 800));
    other.loadSample();
    expect(v.scale, isNot(1));
    other.clear();
    expect(chained, 2);
    expect(v.scale, 1);
    expect(v.centerX, 0);
    v.dispose();
    other.dispose();
  });

  test('space flag notifies once per change', () {
    var n = 0;
    view.addListener(() => n++);
    view
      ..setSpacePressed(true)
      ..setSpacePressed(true)
      ..setSpacePressed(false);
    expect(n, 2);
  });
}
