import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/domain/entities/geometry.dart';

import '../../../../helpers/pump_app.dart';

const _forbidden = ['Make Offline', 'Offline', 'Online Version', 'Online'];

void expectNoOfflineText() {
  for (final word in _forbidden) {
    expect(
      find.textContaining(word, findRichText: true),
      findsNothing,
      reason: '"$word" must not appear anywhere',
    );
  }
}

const _line = [Point3(1, 2, 3), Point3(4, 5, 6), Point3(7, 8, 9)];

void main() {
  const desktop = Size(1280, 800);

  group('help dialog', () {
    testWidgets('opens, has no offline/online text, closes', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      expectNoOfflineText();

      await tester.tap(find.text('?'));
      await tester.pumpAndSettle();
      expect(find.text('Help & Documentation'), findsOneWidget);
      expect(find.text('Data Import'), findsOneWidget);
      expect(find.text('Version Information'), findsOneWidget);
      expect(
        find.text('Survey Contour Generator | Professional Surveying Tool'),
        findsOneWidget,
      );
      expectNoOfflineText();

      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.text('Help & Documentation'), findsNothing);
    });

    testWidgets('closes on barrier tap and Escape', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);

      await tester.tap(find.text('?'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Help & Documentation'), findsNothing);

      await tester.tap(find.text('?'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Help & Documentation'), findsNothing);
    });
  });

  group('export dialog', () {
    testWidgets('export button is disabled without data', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('Export Options'), findsNothing);
    });

    testWidgets('opens, lists every option and closes', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('Export Options'), findsOneWidget);
      for (final t in [
        'AutoLISP Script',
        'Civil 3D Script',
        'DXF R12',
        'PNG Image',
        'BMP Bitmap',
        'Print',
        'Breaklines to Excel',
      ]) {
        expect(find.text(t), findsOneWidget);
      }
      expectNoOfflineText();

      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.text('Export Options'), findsNothing);
    });

    testWidgets('DXF export saves a file and closes the dialog', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DXF R12'));
      await tester.pumpAndSettle();

      expect(h.files.saved, hasLength(1));
      expect(h.files.saved.single.fileName, endsWith('-R12.dxf'));
      expect(find.text('Export Options'), findsNothing);
      expect(
        find.text('✓ DXF R12 exported (max compatibility)'),
        findsOneWidget,
      );
    });

    testWidgets('AutoLISP and Civil 3D exports save and close', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);

      for (final (label, ext) in [
        ('AutoLISP Script', '.lsp'),
        ('Civil 3D Script', '.scr'),
      ]) {
        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(h.files.saved.last.fileName, endsWith(ext));
        expect(find.text('Export Options'), findsNothing);
      }
    });

    testWidgets('Excel export without breaklines warns and stays open', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Breaklines to Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Breaklines to Excel'));
      await tester.pump();
      expect(find.text('⚠ No breaklines'), findsOneWidget);
      expect(find.text('Export Options'), findsOneWidget);
      expect(h.files.saved, isEmpty);
    });

    // Real rendering (dart:ui toImage) completes outside the fake-async zone.
    Future<void> waitUntil(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 600 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(done(), isTrue, reason: 'export did not finish in time');
    }

    Future<void> openExport(WidgetTester tester, AppHarness h) async {
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
    }

    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

    testWidgets('PNG export saves a real PNG and closes the dialog', (
      tester,
    ) async {
      final h = AppHarness();
      await openExport(tester, h);
      await tester.tap(find.text('PNG Image'));
      await waitUntil(tester, () => h.files.saved.isNotEmpty);
      await tester.pumpAndSettle();

      final f = h.files.saved.single;
      expect(f.fileName, endsWith('.png'));
      expect(f.mimeType, 'image/png');
      expect(f.bytes.sublist(0, 8), pngSignature);
      expect(find.text('Export Options'), findsNothing);
      expect(find.text('✓ PNG image exported (3000x3000)'), findsOneWidget);
    });

    testWidgets('BMP export saves a real BMP and closes the dialog', (
      tester,
    ) async {
      final h = AppHarness();
      await openExport(tester, h);
      await tester.tap(find.text('BMP Bitmap'));
      await waitUntil(tester, () => h.files.saved.isNotEmpty);
      await tester.pumpAndSettle();

      final f = h.files.saved.single;
      expect(f.fileName, endsWith('.bmp'));
      expect(f.mimeType, 'image/bmp');
      expect(String.fromCharCodes(f.bytes.sublist(0, 2)), 'BM');
      expect(find.text('Export Options'), findsNothing);
      expect(find.text('✓ BMP image exported (3000x3000)'), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('Print sends a PNG to the print service and closes', (
      tester,
    ) async {
      final h = AppHarness();
      await openExport(tester, h);
      await tester.ensureVisible(find.text('Print'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Print'));
      await waitUntil(tester, () => h.printer.printed.isNotEmpty);
      await tester.pumpAndSettle();

      expect(h.printer.printed.single.sublist(0, 8), pngSignature);
      expect(h.files.saved, isEmpty);
      expect(find.text('Export Options'), findsNothing);
      expect(find.text('✓ Print dialog opened'), findsOneWidget);
    });

    testWidgets('Excel export with breaklines saves an xlsx, stays open', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);
      h.contours.addBreakLine(_line);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Breaklines to Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Breaklines to Excel'));
      await tester.pump();

      final f = h.files.saved.single;
      expect(f.fileName, startsWith('breaklines-'));
      expect(f.fileName, endsWith('.xlsx'));
      expect(f.bytes.sublist(0, 2), [0x50, 0x4B]); // zip container "PK"
      expect(find.text('Export Options'), findsOneWidget);
      expect(find.text('✓ Excel exported'), findsOneWidget);
    });

    testWidgets('a cancelled save keeps the dialog open without a toast', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);
      h.files.saveResult = false;
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DXF R12'));
      await tester.pumpAndSettle();
      expect(find.text('Export Options'), findsOneWidget);
      expect(find.textContaining('exported'), findsNothing);
    });

    testWidgets('a failing save shows the failure toast, keeps the dialog', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);
      h.files.saveError = StateError('disk full');
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AutoLISP Script'));
      await tester.pumpAndSettle();
      expect(find.text('Export Options'), findsOneWidget);
      expect(find.textContaining('✕ Export failed'), findsOneWidget);
    });
  });

  group('breakline points dialog', () {
    testWidgets('edits, validates and commits values', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);
      h.contours.addBreakLine(_line);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('✎ Draw'));
      await tester.pump();
      await tester.tap(find.text('✏️ Edit'));
      await tester.pumpAndSettle();
      expect(find.text('BL-1 - Edit Points'), findsOneWidget);
      expect(find.text('X (Easting)'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);

      final fields = find.byType(EditableText);
      // Valid edit commits on Enter.
      await tester.tap(fields.at(0));
      await tester.enterText(fields.at(0), '12.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(h.contours.breakLines.single.points.first.x, 12.5);

      // Letters are rejected by the formatter.
      await tester.enterText(fields.at(1), 'abc');
      await tester.pump();
      expect(
        tester.widget<EditableText>(fields.at(1)).controller.text,
        '2.000',
      );

      // Invalid number reverts on blur.
      await tester.enterText(fields.at(2), '-');
      await tester.tap(fields.at(3));
      await tester.pump();
      expect(
        tester.widget<EditableText>(fields.at(2)).controller.text,
        '3.000',
      );

      await tester.tap(find.text('✓ Done'));
      await tester.pumpAndSettle();
      expect(find.text('BL-1 - Edit Points'), findsNothing);
      expect(find.text('✓ Breakline points saved'), findsOneWidget);
    });

    testWidgets('commits pending text when closed with Done', (tester) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);
      h.contours.addBreakLine(_line);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('✎ Draw'));
      await tester.pump();
      await tester.tap(find.text('✏️ Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(2), '99.5');
      await tester.tap(find.text('✓ Done'));
      await tester.pumpAndSettle();
      expect(h.contours.breakLines.single.points.first.z, 99.5);
    });

    testWidgets('deleting a breakline removes it from the list', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, size: desktop);
      await h.loadSample(tester);
      h.contours.addBreakLine(_line);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('✎ Draw'));
      await tester.pump();
      expect(find.text('BL-1'), findsOneWidget);
      await tester.tap(find.text('×'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('BL-1'), findsNothing);
      expect(find.text('No breaklines yet. Draw one above!'), findsOneWidget);
    });
  });

  testWidgets('no offline text on any tab', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: desktop);
    await h.loadSample(tester);
    for (final t in [
      '≡ Data',
      '⚙ Settings',
      '✎ Draw',
      '◔ Analysis',
      '☰ Layers',
    ]) {
      await tester.tap(find.text(t));
      await tester.pump();
      expectNoOfflineText();
    }
  });
}
