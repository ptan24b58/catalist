import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/logger.dart';

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
}
