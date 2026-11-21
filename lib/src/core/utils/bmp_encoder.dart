import 'dart:typed_data';

/// Minimal 24-bit BMP writer (reference `convertToBMP`, lines 2572–2620).
///
/// Output is a top-down (negative height) BITMAPINFOHEADER bitmap with BGR
/// pixels and rows padded to 4 bytes, 2835 px/m (72 DPI).
abstract final class BmpEncoder {
  static const int headerSize = 54;
  static const int _dibSize = 40;
  static const int _pixelsPerMeter = 2835;

  /// Total file size for an image of [width] x [height].
  static int fileSizeFor(int width, int height) =>
      headerSize + _rowStride(width) * height;

  static int _rowStride(int width) => width * 3 + (4 - (width * 3) % 4) % 4;

  /// Encodes straight (unassociated) RGBA bytes; alpha is ignored.
  static Uint8List encodeRgba(Uint8List rgba, int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image size must be positive: ${width}x$height');
    }
    if (rgba.length != width * height * 4) {
      throw ArgumentError(
        'Expected ${width * height * 4} RGBA bytes, got ${rgba.length}',
      );
    }
    final stride = _rowStride(width);
    final pixelDataSize = stride * height;
    final out = Uint8List(headerSize + pixelDataSize);
    _writeHeader(ByteData.sublistView(out), width, height, pixelDataSize);
    _writePixels(out, rgba, width, height, stride);
    return out;
  }

  static void _writeHeader(ByteData v, int width, int height, int dataSize) {
    v
      ..setUint16(0, 0x4D42, Endian.little) // "BM"
      ..setUint32(2, headerSize + dataSize, Endian.little)
      ..setUint32(6, 0, Endian.little)
      ..setUint32(10, headerSize, Endian.little)
      ..setUint32(14, _dibSize, Endian.little)
      ..setInt32(18, width, Endian.little)
      ..setInt32(22, -height, Endian.little)
      ..setUint16(26, 1, Endian.little)
      ..setUint16(28, 24, Endian.little)
      ..setUint32(30, 0, Endian.little)
      ..setUint32(34, dataSize, Endian.little)
      ..setInt32(38, _pixelsPerMeter, Endian.little)
      ..setInt32(42, _pixelsPerMeter, Endian.little)
      ..setUint32(46, 0, Endian.little)
      ..setUint32(50, 0, Endian.little);
  }

  static void _writePixels(
    Uint8List out,
    Uint8List rgba,
    int width,
    int height,
    int stride,
  ) {
    for (var y = 0; y < height; y++) {
      var o = headerSize + y * stride;
      var i = y * width * 4;
      for (var x = 0; x < width; x++) {
        out[o++] = rgba[i + 2];
        out[o++] = rgba[i + 1];
        out[o++] = rgba[i];
        i += 4;
      }
    }
  }
}
