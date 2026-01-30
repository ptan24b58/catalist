import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Triggers native widget update via platform channel.
class WidgetUpdater {
  static const _channel = MethodChannel('com.catalist/widget');

  /// Request the native side to regenerate the widget snapshot and refresh.
  static Future<void> update() async {
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      // Non-fatal: widget update is best-effort (e.g. no widgets placed)
      AppLogger.debug('Widget update skipped: $e');
    }
  }
}
