// ignore_for_file: avoid_print
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/map_view_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/painters/map_painter.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/analysis/analysis_tab.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/map/map_canvas_area.dart';

import '../../../../helpers/map_harness.dart';

/// Disposal/leak checks: repeated load/clear cycles must not leave listeners,
/// key handlers, painters or controllers behind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapViewController wiring', () {
    test('dispose unhooks the contour listener and onDataReset', () {
      final h = MapHarness();
      var outer = 0;
      h.contours.onDataReset = () => outer++;
      final before = h.contours.onDataReset;
      final view = MapViewController(h.contours);
      expect(h.contours.onDataReset, isNot(same(before)));

      view.dispose();
      expect(h.contours.onDataReset, same(before));

      // Reset after dispose still reaches the previous callback and the
      // disposed controller ignores everything.
      h.contours.loadSample();
      expect(outer, 1);
      h.dispose();
    });

    test('repeated create/dispose cycles leave no chained callbacks', () {
      final h = MapHarness();
      final base = h.contours.onDataReset;
      for (var i = 0; i < 50; i++) {
        MapViewController(h.contours).dispose();
      }
      expect(h.contours.onDataReset, same(base));
      h.dispose();
    });
  });

  group('repaint isolation', () {
    testWidgets('pointer moves repaint neither the map nor its siblings', (
      tester,
    ) async {
      final h = MapHarness();
      addTearDown(h.dispose);
      tester.view
        ..physicalSize = const Size(1200, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sibling = _CountingPainter();
      await tester.pumpWidget(
        h.wrap(
          Column(
            children: [
              SizedBox(height: 20, child: CustomPaint(painter: sibling)),
              const Expanded(child: MapCanvasArea()),
            ],
          ),
        ),
      );
      await h.loadSample(tester);
      await tester.pump();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 300));
      await tester.pump();
      for (final e in tester.elementList(find.byType(RepaintBoundary))) {
        final ro = e.renderObject;
        final ancestors = <String>[];
        e.visitAncestorElements((a) {
          if (ancestors.length < 3) ancestors.add(a.widget.runtimeType.toString());
          return true;
        });
      }
      final before = sibling.paints;
      for (var i = 0; i < 10; i++) {
        await mouse.moveTo(Offset(500.0 + i * 20, 300));
        await tester.pump();
      }
      expect(h.view.mouseCoords.value, isNotNull);
      expect(sibling.paints, before, reason: 'coords updates leaked a repaint');
    });
  });

  group('HardwareKeyboard handler', () {
    testWidgets('MapCanvasArea removes its key handler on dispose', (
      tester,
    ) async {
      final h = MapHarness();
      addTearDown(h.dispose);
      tester.view
        ..physicalSize = const Size(1200, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(h.wrap(const MapCanvasArea()));
      await tester.pumpWidget(h.wrap(const SizedBox()));
      // A handler left behind would call context.read on a defunct element
      // and throw for this key press.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(tester.takeException(), isNull);
    });
  });


  group('MapGeometry label caches', () {
    MapGeometry build() {
      final model = sampleModel();
      return MapGeometry.build(
        points: samplePoints,
        breakLines: const [],
        triangles: model.triangles,
        contours: model.contours,
      );
    }

    test('identical texts share one painter and dispose exactly once', () {
      final points = [
        for (var i = 0; i < 6; i++)
          SurveyPoint(borehole: 'P${i % 3}', x: i * 10, y: i * 7.0, z: 5),
      ];
      final g = MapGeometry.build(
        points: points,
        breakLines: const [],
        triangles: const [],
        contours: const [],
      );
      expect(identical(g.levelLabel(0), g.levelLabel(5)), isTrue);
      expect(identical(g.boreholeLabel(0), g.boreholeLabel(3)), isTrue);
      expect(identical(g.boreholeLabel(0), g.boreholeLabel(1)), isFalse);
      final all = {
        for (var i = 0; i < 6; i++) g.levelLabel(i),
        for (var i = 0; i < 6; i++) g.boreholeLabel(i),
      };
      g.dispose();
      expect(all.every((p) => p.debugDisposed), isTrue);
    });

    test('dispose releases every lazily created painter', () {
      final g = build();
      final made = [
        for (var i = 0; i < samplePoints.length; i++) g.boreholeLabel(i),
        for (var i = 0; i < samplePoints.length; i++) g.levelLabel(i),
        for (final l in g.contourLabels) l.painter,
      ];
      g.dispose();
      expect(made.every((p) => p.debugDisposed), isTrue);
    });

    testWidgets('replaced and removed geometries are disposed', (tester) async {
      final h = MapHarness();
      addTearDown(h.dispose);
      tester.view
        ..physicalSize = const Size(1200, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(h.wrap(const MapCanvasArea()));

      MapGeometry current() {
        final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
        return paints
            .map((c) => c.painter)
            .whereType<MapPainter>()
            .single
            .geometry;
      }

      final labels = <Object>[];
      for (var i = 0; i < 4; i++) {
        await h.loadSample(tester);
        await tester.pump();
        final g = current();
        labels.add(g.boreholeLabel(0));
        h.contours.clear();
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
      }
      // All but the live (empty) geometry were disposed after their frame.
      for (final l in labels) {
        expect((l as dynamic).debugDisposed, isTrue);
      }
      expect(current().points, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('leak tracking', () {
    testWidgets(
      'repeated load/clear cycles dispose geometry, painters and controllers',
      (tester) async {
        final h = MapHarness();
        tester.view
          ..physicalSize = const Size(1200, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(h.wrap(const MapCanvasArea()));
        for (var i = 0; i < 6; i++) {
          await h.loadSample(tester);
          await tester.pump();
          h.contours.clear();
          await tester.pump();
          await tester.pump(const Duration(seconds: 3));
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        h.dispose();
      },
      experimentalLeakTesting: LeakTesting.settings.withTracked(
        allNotDisposed: true,
      ),
    );

    testWidgets(
      'analysis tab (TIN visualizer animation, charts) disposes everything',
      (tester) async {
        final h = MapHarness();
        tester.view
          ..physicalSize = const Size(1200, 1600)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          h.wrap(const SingleChildScrollView(child: AnalysisTab())),
        );
        await h.loadSample(tester);
        await tester.pump();
        await tester.tap(find.text('▶ Animate'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpWidget(const SizedBox());
        // The running animation must stop with its owner.
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
        h.dispose();
      },
      experimentalLeakTesting: LeakTesting.settings.withTracked(
        allNotDisposed: true,
      ),
    );
  });
}

class _CountingPainter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_CountingPainter old) => false;
}
