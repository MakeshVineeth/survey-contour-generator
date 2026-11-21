import 'dart:async';
import 'dart:typed_data';

import 'package:survey_contour_generator/src/core/platform/compute_runner.dart';
import 'package:survey_contour_generator/src/core/platform/file_service.dart';
import 'package:survey_contour_generator/src/core/platform/print_service.dart';

final class SavedFile {
  const SavedFile(this.fileName, this.bytes, this.mimeType);

  final String fileName;
  final Uint8List bytes;
  final String mimeType;
}

final class FakeFileService implements FileService {
  PickedFile? picked;
  Object? pickError;
  bool saveResult = true;
  Object? saveError;
  final List<SavedFile> saved = [];

  @override
  Future<PickedFile?> pickSpreadsheet() async {
    final err = pickError;
    if (err != null) throw err;
    return picked;
  }

  @override
  Future<bool> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final err = saveError;
    if (err != null) throw err;
    saved.add(SavedFile(fileName, bytes, mimeType));
    return saveResult;
  }
}

final class FakePrintService implements PrintService {
  final List<Uint8List> printed = [];

  @override
  Future<void> printPng(Uint8List png) async => printed.add(png);
}

/// Runs inline after an event-loop turn; in manual mode results are held until
/// the test releases them, to control completion order.
final class FakeComputeRunner implements ComputeRunner {
  FakeComputeRunner({this.manual = false});

  final bool manual;
  final List<void Function()> pending = [];

  @override
  Future<R> run<Q, R>(R Function(Q) fn, Q message) {
    if (!manual) return Future<R>(() => fn(message));
    final completer = Completer<R>();
    pending.add(() => completer.complete(fn(message)));
    return completer.future;
  }
}

PickedFile pickedFromBytes(String name, Uint8List bytes, {int? size}) =>
    PickedFile(
      name: name,
      size: size ?? bytes.length,
      readBytes: () async => bytes,
    );
