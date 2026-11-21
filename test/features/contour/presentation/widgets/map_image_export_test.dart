import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/map/map_image_export.dart';

import '../../../../helpers/map_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MapHarness h;

  setUp(() => h = MapHarness());
  tearDown(() => h.dispose());

  Future<BuildContext> pumpWithData(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      h.wrap(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await h.loadSample(tester);
    return captured;
  }

  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  int bigEndian32(Uint8List b, int offset) =>
      (b[offset] << 24) |
      (b[offset + 1] << 16) |
      (b[offset + 2] << 8) |
      b[offset + 3];

  testWidgets('png is a 3000x3000 PNG', (tester) async {
    final context = await pumpWithData(tester);
    final bytes = (await tester.runAsync(() => MapImageExport.png(context)))!;
    expect(bytes.sublist(0, 8), pngSignature);
    expect(bigEndian32(bytes, 16), 3000);
    expect(bigEndian32(bytes, 20), 3000);
  });

  testWidgets('printPng is a 2000x2000 PNG', (tester) async {
    final context = await pumpWithData(tester);
    final bytes = (await tester.runAsync(
      () => MapImageExport.printPng(context),
    ))!;
    expect(bytes.sublist(0, 8), pngSignature);
    expect(bigEndian32(bytes, 16), 2000);
  });

  testWidgets('bmp is a 3000x3000 24-bit top-down BMP', (tester) async {
    final context = await pumpWithData(tester);
    final bytes = (await tester.runAsync(() => MapImageExport.bmp(context)))!;
    final view = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 2)), 'BM');
    expect(view.getInt32(18, Endian.little), 3000);
    expect(view.getInt32(22, Endian.little), -3000);
    expect(bytes.length, 54 + 9000 * 3000);
    // The background is white: the first pixel is B=G=R=255.
    expect(bytes.sublist(54, 57), [255, 255, 255]);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
