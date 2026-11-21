import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';

import '../../../../helpers/pump_app.dart';

const _tabs = ['≡ Data', '⚙ Settings', '✎ Draw', '◔ Analysis', '☰ Layers'];

void main() {
  group('mobile layout (390x844)', () {
    const phone = Size(390, 844);

    testWidgets('shows menu button; drawer opens and closes', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: phone);

      // Compact header: menu button, icon-only actions.
      expect(find.text('☰'), findsOneWidget);
      expect(find.text('Export'), findsNothing);
      expect(find.text('📤'), findsOneWidget);
      expect(find.textContaining('v12', findRichText: true), findsNothing);

      // Closed: the sidebar is parked off-screen to the left.
      expect(tester.getTopLeft(find.text('≡ Data')).dx, lessThan(0));

      await tester.tap(find.text('☰'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('≡ Data')).dx,
        greaterThanOrEqualTo(0),
      );
      expect(tester.getSize(find.text('IMPORT DATA')).width, greaterThan(0));

      // Tapping the dim overlay closes it again.
      await tester.tapAt(const Offset(380, 400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('≡ Data')).dx, lessThan(0));
    });

    testWidgets('tabs work inside the drawer', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: phone);
      await tester.tap(find.text('☰'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('⚙ Settings'));
      await tester.pump();
      expect(find.text('CONTOUR SETTINGS'), findsOneWidget);
    });

    testWidgets('help dialog opens from the compact header', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: phone);
      await tester.tap(find.text('?'));
      await tester.pumpAndSettle();
      expect(find.text('Help & Documentation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('responsive overflow', () {
    const sizes = <Size>[
      Size(320, 568),
      Size(390, 844),
      Size(673, 841),
      Size(800, 1280),
      Size(1280, 800),
      Size(1920, 1080),
    ];

    for (final size in sizes) {
      for (final tab in _tabs) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} $tab', (
          tester,
        ) async {
          final h = AppHarness();
          await h.pump(tester, size: size);
          await h.loadSample(tester);
          h.contours.addBreakLine(const [Point3(1, 2, 3), Point3(4, 5, 6)]);
          h.draw.toggleDrawMode();
          h.draw.addPoint(const Point3(10, 20, 30));
          await tester.pump(const Duration(milliseconds: 50));

          if (size.width <= 768) {
            await tester.tap(find.text('☰').first);
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          if (tab == '≡ Data') {
            h.display.showAllBoreholes = true;
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  });
}
