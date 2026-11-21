import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:survey_contour_generator/src/core/utils/js_number.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/dialogs/expanded_chart_dialog.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/dialogs/stat_details_dialog.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/analysis/analysis_tab.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/panels/data_tab.dart'
    show StatKind;

import '../../../../helpers/map_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MapHarness h;

  setUpAll(loadAppFonts);
  setUp(() => h = MapHarness());
  tearDown(() => h.dispose());

  Future<void> pumpTab(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(400, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      h.wrap(
        const SingleChildScrollView(
          child: Padding(padding: EdgeInsets.all(16), child: AnalysisTab()),
        ),
      ),
    );
  }

  testWidgets('shows the placeholder without data', (tester) async {
    await pumpTab(tester);
    expect(find.text('Import data to view terrain analysis'), findsOneWidget);
    expect(find.textContaining('TIN Construction'), findsNothing);
  });

  testWidgets('shows stat values, summary and charts for sample data', (
    tester,
  ) async {
    await pumpTab(tester);
    await h.loadSample(tester);
    await tester.pump();
    expect(tester.takeException(), isNull);

    final stats = h.contours.model.stats!;
    expect(find.text('🗺 Terrain Overview'), findsOneWidget);
    expect(
      find.text('${stats.pointCount} / ${stats.triangleCount}'),
      findsOneWidget,
    );
    expect(find.text('${stats.area.toFixed(1)} m²'), findsOneWidget);
    expect(find.text('${stats.elevation.min.toFixed(2)} m'), findsOneWidget);
    expect(find.text('${stats.elevation.max.toFixed(2)} m'), findsOneWidget);
    expect(find.text('${stats.slope.avgDeg.toFixed(1)}°'), findsOneWidget);
    expect(
      find.text('${stats.terrainType.name.toUpperCase()} TERRAIN'),
      findsOneWidget,
    );
    expect(find.text('Flat: ${stats.slopeDistribution.flat}'), findsOneWidget);
    expect(find.text('📊 Elevation Profile'), findsOneWidget);
    expect(find.text('📐 Slope Distribution'), findsOneWidget);
    expect(find.text('🤖 AI Terrain Analysis'), findsOneWidget);
    expect(find.text('Smart Summary'), findsOneWidget);
    expect(find.text(h.contours.summary!.paragraphs.first), findsOneWidget);
  });

  testWidgets('TIN visualizer animates, replays and resets', (tester) async {
    await pumpTab(tester);
    await h.loadSample(tester);
    await tester.pump();

    expect(find.text('▶ Animate'), findsOneWidget);
    expect(find.text('↺ Reset'), findsNothing);

    await tester.tap(find.text('▶ Animate'));
    await tester.pump();
    expect(find.text('● Playing...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('● Playing...'), findsOneWidget);
    expect(find.text('↺ Reset'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('▶ Replay'), findsOneWidget);

    await tester.tap(find.text('▶ Replay'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('● Playing...'), findsOneWidget);
    await tester.tap(find.text('↺ Reset'));
    await tester.pump();
    expect(find.text('▶ Animate'), findsOneWidget);

    // Leaving mid-animation must dispose the ticker without errors.
    await tester.tap(find.text('▶ Animate'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart tooltips follow taps', (tester) async {
    await pumpTab(tester);
    await h.loadSample(tester);
    await tester.pump();
    final chart = find.text('📊 Elevation Profile');
    await tester.tapAt(tester.getCenter(chart) + const Offset(0, 100));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded chart modals open and close', (tester) async {
    await pumpTab(tester);
    await h.loadSample(tester);
    await tester.pump();

    for (final kind in ExpandedChartKind.values) {
      final context = tester.element(find.byType(AnalysisTab));
      unawaited(ExpandedChartDialog.show(context, kind));
      await tester.pump();
      await tester.pump();
      final title = find.descendant(
        of: find.byType(ExpandedChartDialog),
        matching: find.text(ExpandedChartDialog.titleOf(kind)),
      );
      expect(title, findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpandedChartDialog), findsNothing);
    }
  });

  testWidgets('stat details modals show reference values', (tester) async {
    await pumpTab(tester);
    await h.loadSample(tester);
    await tester.pump();
    h.contours.addBreakLine(const [Point3(0, 0, 1), Point3(3, 4, 2)]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    Future<void> open(StatKind kind) async {
      final context = tester.element(find.byType(AnalysisTab));
      unawaited(showStatDetailsDialog(context, kind));
      await tester.pump();
      await tester.pump();
    }

    await open(StatKind.boreholes);
    expect(find.text('📍 Borehole Statistics'), findsOneWidget);
    expect(find.textContaining('93.500m', findRichText: true), findsOneWidget);
    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();

    await open(StatKind.breaklines);
    expect(find.textContaining('5.00m', findRichText: true), findsWidgets);
    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();

    await open(StatKind.triangles);
    expect(find.text('△ Triangle Statistics'), findsOneWidget);
    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();

    await open(StatKind.contours);
    expect(find.textContaining('Every 1m', findRichText: true), findsOneWidget);
    expect(find.textContaining('Every 5m', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
