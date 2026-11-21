import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../utils/app_logger.dart';
import 'file_name.dart';
import 'file_service.dart';
import 'spreadsheet_picker.dart';

FileService createFileService() => const _IoFileService();

/// Android / Windows: native pickers and the system save dialog.
final class _IoFileService implements FileService {
  const _IoFileService();

  @override
  Future<PickedFile?> pickSpreadsheet() => pickSpreadsheetFile();

  @override
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: sanitizeFileName(fileName),
        bytes: bytes,
        mimeType: mimeType,
      );
      return uri != null;
    } on Object catch (e, s) {
      AppLogger.error('saveFile failed', e, s);
      return false;
    }
  }
}
