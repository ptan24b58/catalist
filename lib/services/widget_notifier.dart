import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/logger.dart';
import 'service_locator.dart';

/// Service to notify native widgets to update
class WidgetNotifier {
  static const MethodChannel _channel = MethodChannel('com.catalist/widget');

  /// Notify native widget to refresh
  static Future<void> notifyWidgetUpdate() async {
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      // Method channel might not be set up yet, silently fail
      AppLogger.debug('Widget update notification failed: $e');
    }
  }

  /// Regenerate snapshot and notify widget (for time-based updates)
  static Future<void> regenerateSnapshot() async {
    if (kIsWeb) return;

    try {
      // Regenerate snapshot on Flutter side
      await widgetUpdateEngine.regenerateSnapshot();
      // Then notify native widget to refresh
      await _channel.invokeMethod('regenerateSnapshot');
    } catch (e) {
      AppLogger.debug('Snapshot regeneration failed: $e');
    }
  }
}
