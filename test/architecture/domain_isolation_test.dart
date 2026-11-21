import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Domain layers must stay pure Dart: no Flutter UI or platform plugin imports.
void main() {
  test('domain/ files import no Flutter UI or platform packages', () {
    final forbidden = RegExp(
      r'''import\s+['"]package:(flutter/|material_ui/|dart:ui|[a-z_]+_(android|web|platform_interface))''',
    );
    final forbiddenDartUi = RegExp(
      r'''import\s+['"]dart:(ui|html|js_interop)''',
    );
    final offenders = <String>[];

    final features = Directory('lib/src/features');
    for (final entity in features.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll(r'\', '/');
      if (!normalized.contains('/domain/')) continue;
      final source = entity.readAsStringSync();
      if (forbidden.hasMatch(source) || forbiddenDartUi.hasMatch(source)) {
        offenders.add(normalized);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Forbidden imports in domain/: $offenders',
    );
  });
}
