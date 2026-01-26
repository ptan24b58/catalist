import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/logger.dart';

/// Service to notify native widgets to update
class WidgetNotifier {
  static const MethodChannel _channel = MethodChannel('com.catalist/widget');

  /// Notify native widget to refresh
  static Future<void> notifyWidgetUpdate() async {
    if (kIsWeb) {
      AppLogger.debug('Widget notification skipped (web platform)');
      return;
    }

    try {
      print('📡 [WIDGET] Sending update notification to native widget...');
      await _channel.invokeMethod('updateWidget');
      print('✅ [WIDGET] Widget update notification sent to native');
    } catch (e) {
      // Method channel might not be set up yet, log but don't fail
      print('⚠️ [WIDGET] Widget update notification failed (may not be set up): $e');
    }
  }
}
