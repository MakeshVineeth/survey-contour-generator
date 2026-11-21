import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/draw_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/map/map_canvas_area.dart';

import '../../../../helpers/map_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MapHarness h;

  setUpAll(loadAppFonts);

  setUp(() => h = MapHarness());
  tearDown(() => h.dispose());

  Future<void> pumpAt(WidgetTester tester, double w, double hgt) async {
    tester.view
      ..physicalSize = Size(w, hgt)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(h.wrap(const MapCanvasArea()));
  }

  for (final size in [const Size(320, 568), const Size(1920, 1080)]) {
    testWidgets('renders empty and loaded at ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      await pumpAt(tester, size.width, size.height);
      expect(find.text('No data'), findsOneWidget);
      expect(find.text('Legend'), findsNothing);

      await h.loadSample(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Legend'), findsOneWidget);
      expect(find.textContaining('tri |'), findsOneWidget);
      expect(find.text('⛶ Fit'), findsOneWidget);

      // Draw mode adds the indicator, toggle and DRAWING badge.
      h.draw.toggleDrawMode();
      await tester.pump();
      expect(find.text('● DRAWING'), findsOneWidget);
      expect(find.text('➕ Add Point'), findsOneWidget);
      expect(find.text('✏️ Click to add points (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('toolbar zoom buttons change the scale and need data', (
    tester,
  ) async {
    await pumpAt(tester, 1200, 800);
    await tester.tap(find.text('＋'));
    await tester.pump();
    expect(h.view.scale, 1);

    await h.loadSample(tester);
    await tester.pump();
    final fitted = h.view.scale;
    await tester.tap(find.text('＋'));
    await tester.pump();
    expect(h.view.scale, closeTo(fitted * 1.3, 1e-9));
    await tester.tap(find.text('－'));
    await tester.pump();
    expect(h.view.scale, closeTo(fitted, 1e-9));
    await tester.tap(find.text('＋'));
    await tester.tap(find.text('⛶ Fit'));
    await tester.pump();
    expect(h.view.scale, closeTo(fitted, 1e-9));
  });

  testWidgets('wheel zooms, drag pans, hover shows coordinates', (
    tester,
  ) async {
    await pumpAt(tester, 1200, 800);
    await h.loadSample(tester);
    await tester.pump();
    final area = find.byType(MapCanvasArea);
    final center = tester.getCenter(area);
    final before = h.view.scale;

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));
    await tester.pump();
    expect(find.textContaining('X: '), findsOneWidget);

    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pump();
    expect(h.view.scale, closeTo(before * 1.15, 1e-9));

    final cx = h.view.centerX;
    await tester.dragFrom(center, const Offset(60, 0));
    await tester.pump();
    expect(h.view.centerX, lessThan(cx));
  });

  testWidgets('pinch zooms with two pointers', (tester) async {
    await pumpAt(tester, 1200, 800);
    await h.loadSample(tester);
    await tester.pump();
    final c = tester.getCenter(find.byType(MapCanvasArea));
    final before = h.view.scale;
    final a = await tester.startGesture(c - const Offset(50, 0));
    final b = await tester.startGesture(c + const Offset(50, 0));
    await b.moveBy(const Offset(10, 0)); // sets the reference distance
    await b.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(h.view.scale, greaterThan(before));
    await a.up();
    await b.up();
  });

  testWidgets('draw mode taps add points; Space switches to pan mode', (
    tester,
  ) async {
    await pumpAt(tester, 1200, 800);
    await h.loadSample(tester);
    await tester.pump();
    h.draw.toggleDrawMode();
    await tester.pump();

    final c = tester.getCenter(find.byType(MapCanvasArea));
    await tester.tapAt(c);
    await tester.pump();
    expect(h.draw.currentBreakline, hasLength(1));
    final p = h.draw.currentBreakline.single;
    expect(p.x, closeTo(h.view.centerX, 1.5));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(h.view.spacePressed, isTrue);
    expect(h.draw.mobileDrawMode, MobileDrawMode.navigate);
    expect(
      find.text('🧭 Pan/Zoom mode - switch to Add Point to continue'),
      findsOneWidget,
    );
    await tester.tapAt(c);
    await tester.pump();
    expect(h.draw.currentBreakline, hasLength(1));

    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(h.view.spacePressed, isFalse);
    expect(h.draw.mobileDrawMode, MobileDrawMode.add);
    await tester.pump(const Duration(seconds: 3)); // toast timer
  });

  testWidgets('mode buttons switch between add and navigate', (tester) async {
    await pumpAt(tester, 1200, 800);
    await h.loadSample(tester);
    h.draw.toggleDrawMode();
    await tester.pump();
    await tester.tap(find.text('🧭 Pan/Zoom'));
    await tester.pump();
    expect(h.draw.mobileDrawMode, MobileDrawMode.navigate);
    await tester.tap(find.text('➕ Add Point'));
    await tester.pump();
    expect(h.draw.mobileDrawMode, MobileDrawMode.add);
  });
}
