import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';

import '../../../../helpers/pump_app.dart';

const _tabs = ['≡ Data', '⚙ Settings', '✎ Draw', '◔ Analysis', '☰ Layers'];

Finder _logoText() => find.text('ContourGen', findRichText: true);

void main() {
  testWidgets('renders header, title and the five tabs', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(1280, 800));

    expect(_logoText(), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    for (final t in _tabs) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('IMPORT DATA'), findsOneWidget);
    expect(find.text('Click to upload Excel file'), findsOneWidget);
    expect(find.text('.xlsx format only'), findsOneWidget);
  });

  testWidgets('switches between tabs', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(1280, 800));

    await tester.tap(find.text('⚙ Settings'));
    await tester.pump();
    expect(find.text('CONTOUR SETTINGS'), findsOneWidget);
    expect(find.text('Contour Interval (m)'), findsOneWidget);
    expect(find.text('0 = Angular, 10 = Very smooth'), findsOneWidget);
    expect(find.text('IMPORT DATA'), findsNothing);

    await tester.tap(find.text('✎ Draw'));
    await tester.pump();
    expect(find.text('MANUAL BREAKLINE DRAWING'), findsOneWidget);
    expect(find.text('No breaklines yet. Draw one above!'), findsOneWidget);

    await tester.tap(find.text('☰ Layers'));
    await tester.pump();
    expect(find.text('DISPLAY LAYERS'), findsOneWidget);
    expect(find.text('🔺 TIN Mesh'), findsOneWidget);

    await tester.tap(find.text('◔ Analysis'));
    await tester.pump();
    expect(find.text('DISPLAY LAYERS'), findsNothing);

    await tester.tap(find.text('≡ Data'));
    await tester.pump();
    expect(find.text('STATISTICS'), findsOneWidget);
  });

  testWidgets('data tab shows sample statistics and expands the list', (
    tester,
  ) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(1280, 800));
    await h.loadSample(tester);

    expect(find.text('BOREHOLES (12)'), findsOneWidget);
    expect(find.text('+ 2 more... (click to expand)'), findsOneWidget);
    expect(find.text('BH-001'), findsOneWidget);
    expect(find.text('BH-012'), findsNothing);

    await tester.ensureVisible(find.text('+ 2 more... (click to expand)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ 2 more... (click to expand)'));
    await tester.pump();
    expect(find.text('BH-012'), findsOneWidget);
    expect(find.text('▲ Show less'), findsOneWidget);
    expect(h.display.showAllBoreholes, isTrue);
  });

  testWidgets('layer checkboxes drive the display controller', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(1280, 800));
    await tester.tap(find.text('☰ Layers'));
    await tester.pump();

    await tester.tap(find.text('🔺 TIN Mesh'));
    await tester.pump();
    expect(h.display.showTIN, isFalse);
    await tester.tap(find.text('🏷 Labels & RL Values'));
    await tester.pump();
    expect(h.display.showLabels, isFalse);
  });

  testWidgets('settings inputs update the controller', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(1280, 800));
    await tester.tap(find.text('⚙ Settings'));
    await tester.pump();

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '2.5');
    await tester.pump();
    expect(h.contours.interval, 2.5);

    await tester.enterText(fields.at(1), '4');
    await tester.pump();
    expect(h.contours.majorEvery, 4);
    expect(find.text('Major every 10.0m'), findsOneWidget);

    await tester.enterText(fields.at(1), '');
    await tester.pump();
    expect(h.contours.majorEvery, 1);
  });

  testWidgets('draw tab reflects drawing state', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(1280, 800));
    await h.loadSample(tester);
    await tester.tap(find.text('✎ Draw'));
    await tester.pump();

    await tester.tap(find.text('Start Drawing Breakline'));
    await tester.pump();
    expect(h.draw.drawMode, isTrue);
    expect(find.text('● Drawing Mode Active'), findsOneWidget);
    expect(find.text('📍 0 points added'), findsOneWidget);
    expect(find.text('✓ Finish (need 2)'), findsOneWidget);

    h.draw.addPoint(const Point3(1, 2, 3));
    h.draw.addPoint(const Point3(4, 5, 6));
    await tester.pump();
    expect(find.text('📍 2 points added'), findsOneWidget);
    expect(find.text('✓ Finish (✓)'), findsOneWidget);
    expect(find.text('CURRENT BREAKLINE POINTS'), findsOneWidget);

    await tester.tap(find.text('✓ Finish (✓)'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(h.contours.breakLines, hasLength(1));
    expect(find.text('SAVED BREAKLINES (1)'), findsOneWidget);
    expect(find.text('BL-1'), findsOneWidget);
    expect(find.text('2 points'), findsOneWidget);
  });

  testWidgets('toast and file-loading overlays follow the controller', (
    tester,
  ) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(1280, 800));

    h.contours.showToast('✓ Hello');
    await tester.pump();
    expect(find.text('✓ Hello'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('✓ Hello'), findsNothing);
  });
}
