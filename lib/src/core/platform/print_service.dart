import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Sends an image to the system print dialog.
abstract interface class PrintService {
  Future<void> printPng(Uint8List png);
}

/// `package:printing` implementation for every platform.
final class PrintingPrintService implements PrintService {
  const PrintingPrintService();

  @override
  Future<void> printPng(Uint8List png) async {
    final image = pw.MemoryImage(png);
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    await Printing.layoutPdf(
      name: 'contour',
      onLayout: (_) async => doc.save(),
    );
  }
}
