import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/core/theme/app_info.dart';

void main() {
  test('AppInfo.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(AppInfo.version, match!.group(1));
  });

  test('no stale version strings remain in lib/', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains("'12.4'") || text.contains("'12.3'")) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
