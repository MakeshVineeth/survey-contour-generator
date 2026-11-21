import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../utils/app_logger.dart';
import 'file_name.dart';
import 'file_service.dart';
import 'spreadsheet_picker.dart';

FileService createFileService() => const _WebFileService();

/// Web: pick through `file_picker`, save through a Blob download.
final class _WebFileService implements FileService {
  const _WebFileService();

  @override
  Future<PickedFile?> pickSpreadsheet() => pickSpreadsheetFile();

  @override
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    String? url;
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = sanitizeFileName(fileName);
      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      return true;
    } on Object catch (e, s) {
      AppLogger.error('download failed', e, s);
      return false;
    } finally {
      if (url != null) web.URL.revokeObjectURL(url);
    }
  }
}
