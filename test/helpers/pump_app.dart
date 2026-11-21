import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:survey_contour_generator/src/app.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/contour_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/display_settings_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/draw_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/map_view_controller.dart';

import 'fakes.dart';

/// The real [App] wired to fake ports.
final class AppHarness {
  AppHarness() : files = FakeFileService(), printer = FakePrintService() {
    contours = ContourController(
      files: files,
      printer: printer,
      runner: FakeComputeRunner(),
    );
    display = DisplaySettingsController();
    draw = DrawController(contours);
    view = MapViewController(contours);
  }

  final FakeFileService files;
  final FakePrintService printer;
  late final ContourController contours;
  late final DisplaySettingsController display;
  late final DrawController draw;
  late final MapViewController view;

  Widget get app => MultiProvider(
    providers: [
      ChangeNotifierProvider<ContourController>.value(value: contours),
      ChangeNotifierProvider<DisplaySettingsController>.value(value: display),
      ChangeNotifierProvider<DrawController>.value(value: draw),
      ChangeNotifierProvider<MapViewController>.value(value: view),
    ],
    child: const App(),
  );

  Future<void> pump(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(app);
    addTearDown(() async {
      // Let pending toast timers elapse before the controllers go away.
      await tester.pump(const Duration(seconds: 3));
      contours.dispose();
      display.dispose();
      view.dispose();
      draw.dispose();
    });
  }

  /// Loads the sample data and lets the (fake) compute run.
  Future<void> loadSample(WidgetTester tester) async {
    contours.loadSample();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
