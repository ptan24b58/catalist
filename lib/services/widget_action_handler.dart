import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';
import 'service_locator.dart';

// Conditional imports for platform-specific code
import 'dart:io' if (dart.library.html) 'platform_stub.dart' as io;

/// Handles actions triggered from native widgets
class WidgetActionHandler {
  /// Check for pending widget actions and process them
  Future<void> checkAndProcessActions() async {
    // Widgets are only available on mobile platforms
    if (kIsWeb) return;

    try {
      if (_isIOS()) {
        await _processIOSAction();
      } else if (_isAndroid()) {
        await _processAndroidAction();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error processing widget action', e, stackTrace);
    }
  }

  bool _isIOS() {
    if (kIsWeb) return false;
    try {
      return io.Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  bool _isAndroid() {
    if (kIsWeb) return false;
    try {
      return io.Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<void> _processIOSAction() async {
    try {
      // iOS widgets write to App Group
      // In a real implementation, you'd use App Group container
      // For now, we'll check SharedPreferences as fallback
      final prefs = await SharedPreferences.getInstance();
      final actionJson = prefs.getString('widget_action');

      if (actionJson != null) {
        final action = jsonDecode(actionJson) as Map<String, dynamic>;
        await _processAction(action);
        await prefs.remove('widget_action');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error processing iOS action', e, stackTrace);
    }
  }

  Future<void> _processAndroidAction() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final actionFile = io.File('${appDir.path}/widget_action.json');

      if (await actionFile.exists()) {
        final content = await actionFile.readAsString();
        final action = jsonDecode(content) as Map<String, dynamic>;
        await _processAction(action);
        await actionFile.delete();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error processing Android action', e, stackTrace);
    }
  }

  Future<void> _processAction(Map<String, dynamic> action) async {
    try {
      final actionType = action['action'] as String?;
      final goalId = action['goalId'] as String?;

      if (actionType == 'log_progress' && goalId != null) {
        // Validate goal ID before processing
        if (!Validation.isValidGoalId(goalId)) {
          AppLogger.warning('Invalid goal ID in action: $goalId');
          return;
        }

        await goalRepository.logDailyCompletion(goalId, DateTime.now());
        // Snapshot automatically updated by WidgetUpdateEngine
      } else {
        AppLogger.warning('Unknown action type or missing goal ID: $action');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error processing action', e, stackTrace);
      rethrow;
    }
  }

  /// Process action from deep link (e.g., catalist://log?goalId=xxx)
  Future<void> processDeepLink(String? goalId) async {
    if (goalId == null || !Validation.isValidGoalId(goalId)) {
      AppLogger.warning('Invalid goal ID in deep link: $goalId');
      return;
    }

    try {
      await goalRepository.logDailyCompletion(goalId, DateTime.now());
      // Snapshot automatically updated by WidgetUpdateEngine
    } catch (e, stackTrace) {
      AppLogger.error('Error processing deep link', e, stackTrace);
      rethrow;
    }
  }
}
