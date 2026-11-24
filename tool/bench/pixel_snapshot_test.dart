// ignore_for_file: avoid_print
// Run: flutter test tool/bench/pixel_snapshot_test.dart --dart-define=SNAP_OUT=<dir>
// Renders the whole app (sample data, a few states and sizes) to raw RGBA
// files in <dir>, so two code versions can be compared byte for byte.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/map_harness.dart' show loadAppFonts;
import '../../test/helpers/pump_app.dart';

const String _out = String.fromEnvironment('SNAP_OUT');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final size in const [Size(1280, 800), Size(1920, 1080), Size(375, 812)]) {
    testWidgets('snapshot ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      final h = AppHarness();
      final key = GlobalKey();
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(key: key, child: h.app));
      addTearDown(() async {
        await tester.pump(const Duration(seconds: 3));
        h.contours.dispose();
        h.display.dispose();
        h.view.dispose();
        h.draw.dispose();
      });
      await h.loadSample(tester);
      await tester.pump(const Duration(seconds: 1));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset(size.width * 0.7, size.height * 0.5));
      await mouse.moveTo(Offset(size.width * 0.72, size.height * 0.55));
      await tester.pump();

      await _dump(tester, key, 'app_${size.width.toInt()}');
      await tester.pump(const Duration(seconds: 3));
    });
  }
}

Future<void> _dump(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    image.dispose();
    return Uint8List.sublistView(data!);
  }))!;
  if (_out.isEmpty) return;
  Directory(_out).createSync(recursive: true);
  File('$_out/$name.rgba').writeAsBytesSync(bytes);
  print('wrote $name (${bytes.length} bytes)');
}
