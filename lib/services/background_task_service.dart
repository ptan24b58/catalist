import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Service for scheduling background tasks on native platforms
class BackgroundTaskService {
  BackgroundTaskService._(); // Static-only class

  static const MethodChannel _channel = MethodChannel('com.catalist/background');

  /// Schedule a task to run when celebration expires
  /// This ensures the widget updates even when the app is closed
  static Future<void> scheduleCelebrationExpiry(DateTime expiresAt) async {
    if (kIsWeb) return;

    try {
      final delayMs = expiresAt.difference(DateTime.now()).inMilliseconds;
      if (delayMs <= 0) return;

      await _channel.invokeMethod('scheduleCelebrationExpiry', {
        'delayMs': delayMs,
        'expiresAtEpoch': expiresAt.millisecondsSinceEpoch,
      });
      AppLogger.debug('Scheduled celebration expiry for $expiresAt');
    } catch (e) {
      // Method channel might not be set up, silently fail
      AppLogger.debug('Failed to schedule celebration expiry: $e');
    }
  }

  /// Cancel any pending celebration expiry task
  static Future<void> cancelCelebrationExpiry() async {
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('cancelCelebrationExpiry');
    } catch (e) {
      AppLogger.debug('Failed to cancel celebration expiry: $e');
    }
  }

  /// Schedule periodic widget refresh (e.g., for time-based state changes)
  static Future<void> schedulePeriodicRefresh({
    required int intervalMinutes,
  }) async {
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('schedulePeriodicRefresh', {
        'intervalMinutes': intervalMinutes,
      });
      AppLogger.debug('Scheduled periodic refresh every $intervalMinutes minutes');
    } catch (e) {
      AppLogger.debug('Failed to schedule periodic refresh: $e');
    }
  }

  /// Cancel periodic refresh
  static Future<void> cancelPeriodicRefresh() async {
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('cancelPeriodicRefresh');
    } catch (e) {
      AppLogger.debug('Failed to cancel periodic refresh: $e');
    }
  }
}
