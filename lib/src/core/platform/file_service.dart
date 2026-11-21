import 'dart:typed_data';

import 'file_service_io.dart'
    if (dart.library.js_interop) 'file_service_web.dart'
    as impl;

/// A file chosen by the user. Bytes are read lazily so callers can reject
/// oversized files by [size] first.
final class PickedFile {
  const PickedFile({
    required this.name,
    required this.size,
    required this.readBytes,
  });

  final String name;
  final int size;
  final Future<Uint8List> Function() readBytes;
}

/// Platform file access: open and save.
abstract interface class FileService {
  /// Lets the user pick an `.xlsx` / `.xls` file; null when cancelled.
  Future<PickedFile?> pickSpreadsheet();

  /// Saves (or downloads on web) [bytes]. Returns false when cancelled or
  /// failed. [fileName] is sanitized.
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

/// The adapter for the current platform.
FileService createFileService() => impl.createFileService();
