import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug-only logging. Release builds emit nothing.
final class AppLogger {
  const AppLogger._();

  static const String _name = 'ContourGen';

  static void info(String message) {
    if (kDebugMode) developer.log(message, name: _name);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    developer.log(
      message,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
