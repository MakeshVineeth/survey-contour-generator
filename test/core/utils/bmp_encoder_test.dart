import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/core/utils/bmp_encoder.dart';

void main() {
  test('writes header, size and BGR pixels with row padding', () {
    // 3x2 image: width*3 = 9 -> 3 bytes of padding per row.
    final rgba = Uint8List.fromList([
      for (var i = 0; i < 6; i++) ...[i * 10 + 1, i * 10 + 2, i * 10 + 3, 255],
    ]);
    final bmp = BmpEncoder.encodeRgba(rgba, 3, 2);
    final v = ByteData.sublistView(bmp);

    expect(bmp.length, 54 + 12 * 2);
    expect(bmp.length, BmpEncoder.fileSizeFor(3, 2));
    expect(String.fromCharCodes(bmp.sublist(0, 2)), 'BM');
    expect(v.getUint32(2, Endian.little), bmp.length);
    expect(v.getUint32(10, Endian.little), 54);
    expect(v.getUint32(14, Endian.little), 40);
    expect(v.getInt32(18, Endian.little), 3);
    expect(v.getInt32(22, Endian.little), -2);
    expect(v.getUint16(26, Endian.little), 1);
    expect(v.getUint16(28, Endian.little), 24);
    expect(v.getUint32(34, Endian.little), 24);
    expect(v.getInt32(38, Endian.little), 2835);

    // First pixel (R=1,G=2,B=3) is stored as B,G,R.
    expect(bmp.sublist(54, 57), [3, 2, 1]);
    // Padding bytes are zero.
    expect(bmp.sublist(63, 66), [0, 0, 0]);
    // Second row starts right after the padded first row.
    expect(bmp.sublist(66, 69), [33, 32, 31]);
  });

  test('rejects mismatched buffers', () {
    expect(
      () => BmpEncoder.encodeRgba(Uint8List(7), 1, 2),
      throwsArgumentError,
    );
    expect(
      () => BmpEncoder.encodeRgba(Uint8List(0), 0, 1),
      throwsArgumentError,
    );
  });
}
