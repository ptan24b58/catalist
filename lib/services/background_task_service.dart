import 'package:workmanager/workmanager.dart';

import '../data/goal_repository.dart';
import '../services/widget_snapshot_service.dart';
import '../services/widget_notifier.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Background task names
const String taskRefreshWidget = 'refreshWidget';
const String taskPeriodicRefresh = 'periodicWidgetRefresh';

/// Top-level callback dispatcher for WorkManager
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      AppLogger.debug('Background task executing: $task');

      // Create repository and service for background context
      final goalRepository = GoalRepository();
      final snapshotService = WidgetSnapshotService(goalRepository);

      // Regenerate snapshot
      await snapshotService.generateSnapshot();

      // Notify widget to refresh
      await WidgetNotifier.notifyWidgetUpdate();

      AppLogger.debug('Background task completed: $task');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Background task failed: $task', e, stackTrace);
      return false;
    }
  });
}

/// Service for managing background widget refresh tasks
class BackgroundTaskService {
  static bool _initialized = false;

  /// Initialize WorkManager (call once at app startup)
  static Future<void> initialize() async {
    if (_initialized) return;

    await Workmanager().initialize(callbackDispatcher);
    _initialized = true;
    AppLogger.debug('BackgroundTaskService initialized');
  }

  /// Schedule periodic widget refresh (every 30 minutes)
  static Future<void> schedulePeriodicRefresh() async {
    await Workmanager().registerPeriodicTask(
      taskPeriodicRefresh,
      taskPeriodicRefresh,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    AppLogger.debug('Periodic widget refresh scheduled');
  }

  /// Schedule a one-time refresh at a specific time
  static Future<void> scheduleRefreshAt(DateTime when) async {
    final delay = when.difference(DateTime.now());
    if (delay <= Duration.zero) return;

    await Workmanager().registerOneOffTask(
      '${taskRefreshWidget}_${when.millisecondsSinceEpoch}',
      taskRefreshWidget,
      initialDelay: delay,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    AppLogger.debug('Widget refresh scheduled for $when');
  }

  /// Schedule refreshes at state transition times
  static Future<void> scheduleStateTransitions() async {
    final now = DateTime.now();
    final transitionHours = [
      AppConstants.endOfDayEndHour,    // 5:00
      ...AppConstants.longTermFocusHours, // 14:00, 20:00
      ...AppConstants.longTermFocusHours.map((h) => h + 1), // 15:00, 21:00
      AppConstants.endOfDayStartHour,  // 23:00
    ];

    for (final hour in transitionHours) {
      var targetTime = DateTime(now.year, now.month, now.day, hour);
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }
      await scheduleRefreshAt(targetTime);
    }
  }

  /// Schedule refresh when celebration expires
  static Future<void> scheduleCelebrationExpiry(DateTime expiresAt) async {
    await scheduleRefreshAt(expiresAt);
  }

  /// Cancel all scheduled tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    AppLogger.debug('All background tasks cancelled');
  }
}
