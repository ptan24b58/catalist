import 'package:flutter/foundation.dart';

/// Simple logging utility
class AppLogger {
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    print('[DEBUG] $message');
    if (error != null) {
      print('[ERROR] $error');
      if (stackTrace != null) print('[STACK] $stackTrace');
    }
  }

  static void info(String message) {
    if (kDebugMode) print('[INFO] $message');
  }

  static void warning(String message, [Object? error]) {
    if (!kDebugMode) return;
    print('[WARNING] $message');
    if (error != null) print('[ERROR] $error');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR] $message');
    if (kDebugMode && error != null) {
      print('[ERROR DETAIL] $error');
      if (stackTrace != null) print('[STACK] $stackTrace');
    }
  }
}
