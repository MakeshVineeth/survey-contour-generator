import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/domain/services/contour_model_builder.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/contour_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/display_settings_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/draw_controller.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/controllers/map_view_controller.dart';

import 'fakes.dart';

/// Controllers wired like `main.dart`, backed by fakes.
final class MapHarness {
  MapHarness() {
    contours = ContourController(
      files: FakeFileService(),
      printer: FakePrintService(),
      runner: FakeComputeRunner(),
    );
    display = DisplaySettingsController();
    draw = DrawController(contours);
    view = MapViewController(contours);
  }

  late final ContourController contours;
  late final DisplaySettingsController display;
  late final DrawController draw;
  late final MapViewController view;

  void dispose() {
    view.dispose();
    draw.dispose();
    display.dispose();
    contours.dispose();
  }

  /// Providers + MaterialApp around [child].
  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<ContourController>.value(value: contours),
      ChangeNotifierProvider<DisplaySettingsController>.value(value: display),
      ChangeNotifierProvider<DrawController>.value(value: draw),
      ChangeNotifierProvider<MapViewController>.value(value: view),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );

  /// Loads the sample survey and lets the fake runner finish the model.
  Future<void> loadSample(WidgetTester tester) async {
    contours.loadSample();
    await tester.pump();
    await tester.pump();
    // Let the 2.5 s toast timer finish so no timer outlives the test.
    await tester.pump(const Duration(seconds: 3));
  }
}

/// A model computed synchronously from [samplePoints].
ContourModel sampleModel({List<BreakLine> breakLines = const []}) =>
    ContourModelBuilder.build(
      points: samplePoints,
      breakLines: breakLines,
      interval: 1,
      majorEvery: 5,
      smoothness: 0,
    );

const List<SurveyPoint> samplePoints = [
  SurveyPoint(borehole: 'BH-001', x: 100, y: 100, z: 95.5),
  SurveyPoint(borehole: 'BH-002', x: 150, y: 120, z: 97.2),
  SurveyPoint(borehole: 'BH-003', x: 200, y: 100, z: 99.8),
  SurveyPoint(borehole: 'BH-004', x: 120, y: 180, z: 96.1),
  SurveyPoint(borehole: 'BH-005', x: 180, y: 180, z: 98.4),
  SurveyPoint(borehole: 'BH-006', x: 100, y: 250, z: 94.2),
  SurveyPoint(borehole: 'BH-007', x: 150, y: 250, z: 95.8),
  SurveyPoint(borehole: 'BH-008', x: 200, y: 250, z: 97.5),
];

/// Registers the bundled fonts so layout tests measure real glyph widths
/// (otherwise flutter_test falls back to the very wide Ahem font).
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await load('Outfit', [
    'assets/fonts/outfit/Outfit-Regular.ttf',
    'assets/fonts/outfit/Outfit-Medium.ttf',
    'assets/fonts/outfit/Outfit-SemiBold.ttf',
    'assets/fonts/outfit/Outfit-Bold.ttf',
  ]);
  await load('JetBrainsMono', [
    'assets/fonts/jetbrains_mono/JetBrainsMono-Regular.ttf',
    'assets/fonts/jetbrains_mono/JetBrainsMono-SemiBold.ttf',
  ]);
}
