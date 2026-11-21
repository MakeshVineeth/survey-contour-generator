import 'package:file_picker/file_picker.dart';

import 'file_service.dart';

/// Shared `file_picker` based spreadsheet picker (works on every platform).
Future<PickedFile?> pickSpreadsheetFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
  );
  if (file == null) return null;
  return PickedFile(
    name: file.name,
    size: await file.length() ?? 0,
    readBytes: file.readAsBytes,
  );
}
