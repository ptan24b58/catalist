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

      if (actionJson == null || actionJson.isEmpty) {
        return;
      }

      // Validate JSON before parsing
      if (actionJson.length > 10000) {
        AppLogger.warning('Action JSON too large, potential attack');
        await prefs.remove('widget_action');
        return;
      }

      final decoded = jsonDecode(actionJson);
      if (decoded is! Map<String, dynamic>) {
        AppLogger.warning('Invalid action format: expected Map');
        await prefs.remove('widget_action');
        return;
      }

      await _processAction(decoded);
      await prefs.remove('widget_action');
    } catch (e, stackTrace) {
      AppLogger.error('Error processing iOS action', e, stackTrace);
      // Clean up potentially corrupted data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('widget_action');
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  Future<void> _processAndroidAction() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final actionFile = io.File('${appDir.path}/widget_action.json');

      if (!await actionFile.exists()) {
        return;
      }

      // Validate file size to prevent DoS
      final fileSize = await actionFile.length();
      if (fileSize > 10000) {
        AppLogger.warning('Action file too large, potential attack');
        await actionFile.delete();
        return;
      }

      final content = await actionFile.readAsString();
      if (content.isEmpty) {
        await actionFile.delete();
        return;
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        AppLogger.warning('Invalid action format: expected Map');
        await actionFile.delete();
        return;
      }

      await _processAction(decoded);
      await actionFile.delete();
    } catch (e, stackTrace) {
      AppLogger.error('Error processing Android action', e, stackTrace);
      // Clean up potentially corrupted file
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final actionFile = io.File('${appDir.path}/widget_action.json');
        if (await actionFile.exists()) {
          await actionFile.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  Future<void> _processAction(Map<String, dynamic> action) async {
    final actionType = action['action'] as String?;
    final goalId = action['goalId'] as String?;

    // Validate action type
    if (actionType != 'log_progress') {
      AppLogger.warning('Unknown action type: $actionType');
      return;
    }

    // Validate goal ID before processing
    if (goalId == null || !Validation.isValidGoalId(goalId)) {
      AppLogger.warning('Invalid or missing goal ID in action: $action');
      return;
    }

    await _logProgress(goalId);
  }

  /// Process action from deep link (e.g., catalist://log?goalId=xxx)
  Future<void> processDeepLink(String? goalId) async {
    if (goalId == null || !Validation.isValidGoalId(goalId)) {
      AppLogger.warning('Invalid goal ID in deep link: $goalId');
      return;
    }

    await _logProgress(goalId);
  }

  /// Helper to log progress for a goal
  Future<void> _logProgress(String goalId) async {
    try {
      await goalRepository.logDailyCompletion(goalId, DateTime.now());
    } catch (e, stackTrace) {
      AppLogger.error('Error logging progress', e, stackTrace);
      rethrow;
    }
  }
}
