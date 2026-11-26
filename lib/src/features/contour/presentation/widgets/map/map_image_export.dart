import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/utils/bmp_encoder.dart';
import '../../controllers/contour_controller.dart';
import '../../controllers/display_settings_controller.dart';
import '../../painters/map_export_painter.dart';
import '../../painters/map_painter.dart';

/// Renders the map off-screen exactly like the reference export/print
/// canvases (lines 2299–2620) and returns encoded bytes. Reads the
/// controllers from [BuildContext] via provider (before the first await).
abstract final class MapImageExport {
  /// Edge length of PNG/BMP exports.
  static const int exportSize = 3000;

  /// Edge length of the print image.
  static const int printSize = 2000;

  /// 3000x3000 PNG (reference `exportImage('png')`).
  static Future<Uint8List> png(BuildContext context) =>
      _encodePng(_data(context), exportSize);

  /// 3000x3000 24-bit BMP (reference `exportImage('bmp')`).
  static Future<Uint8List> bmp(BuildContext context) async {
    final data = _data(context);
    final image = await _render(
      exportSize,
      (canvas) =>
          MapExportPainter.paintImage(canvas, exportSize.toDouble(), data),
    );
    final ByteData? bytes;
    try {
      bytes = await image.toByteData();
    } finally {
      // Free the 36 MB raster before the 27 MB BMP is allocated: the pixel
      // copy below is all the encoder needs.
      image.dispose();
    }
    if (bytes == null) throw StateError('Could not read image pixels');
    return BmpEncoder.encodeRgba(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      exportSize,
      exportSize,
    );
  }

  /// 2000x2000 PNG with title block used for printing (`handlePrint`).
  static Future<Uint8List> printPng(BuildContext context) async {
    final data = _data(context);
    final at = DateTime.now();
    final image = await _render(
      printSize,
      (canvas) => MapExportPainter.paintPrint(
        canvas,
        printSize.toDouble(),
        data,
        generatedAt: at,
      ),
    );
    return _toPng(image);
  }

  static MapExportData _data(BuildContext context) {
    final contours = context.read<ContourController>();
    final display = context.read<DisplaySettingsController>();
    return MapExportData(
      points: contours.points,
      breakLines: contours.breakLines,
      triangles: contours.model.triangles,
      contours: contours.model.contours,
      layers: MapLayers(
        tin: display.showTIN,
        contours: display.showContours,
        breakLines: display.showBreakLines,
        labels: display.showLabels,
      ),
    );
  }

  static Future<Uint8List> _encodePng(MapExportData data, int size) async {
    final image = await _render(
      size,
      (canvas) => MapExportPainter.paintImage(canvas, size.toDouble(), data),
    );
    return _toPng(image);
  }

  static Future<ui.Image> _render(
    int size,
    void Function(Canvas canvas) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(size, size);
    } finally {
      picture.dispose();
    }
  }

  static Future<Uint8List> _toPng(ui.Image image) async {
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG encoding failed');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}
