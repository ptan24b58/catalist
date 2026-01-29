import 'dart:async';

import '../data/goal_repository.dart';
import '../domain/goal.dart';
import '../domain/mascot_state.dart';
import '../services/widget_snapshot_service.dart';
import '../services/widget_notifier.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Engine that automatically updates widget snapshots when goals change
/// and schedules time-based refreshes for state transitions.
///
/// Handles:
/// - Goal change events (immediate refresh)
/// - 30-min CTA rotation
/// - End of day boundaries (11pm, 5am)
/// - Long-term focus hours (14:00, 20:00)
/// - Celebration expiry (5 min)
class WidgetUpdateEngine {
  final GoalRepository _goalRepository;
  final WidgetSnapshotService _snapshotService;
  bool _isUpdating = false;
  Future<void>? _pendingUpdate;
  Timer? _nextTransitionTimer;
  Timer? _debounceTimer;
  bool _pendingCelebration = false;
  int _skippedCount = 0;
  DateTime? _lastSkipLogTime;
  DateTime? _celebrationExpiresAt;

  WidgetUpdateEngine(this._goalRepository, this._snapshotService) {
    _goalRepository.setChangeListener(_handleGoalChange);
    _scheduleNextTransition();
  }

  /// Handle goal change events from repository
  Future<void> _handleGoalChange({
    required String event,
    required Goal? goal,
    required String? goalId,
    required bool isCelebration,
  }) async {
    // Track if any update is a celebration
    if (isCelebration) {
      _pendingCelebration = true;
    }
    // Debounce rapid updates (e.g., batch goal saves)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _debounceTimer = null;
      _updateSnapshot(isCelebration: _pendingCelebration);
      _pendingCelebration = false;
    });
  }

  /// Manually trigger snapshot regeneration (e.g., for time-based updates)
  Future<void> regenerateSnapshot() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingCelebration = false;
    await _updateSnapshot(isCelebration: false);
  }

  /// Internal method to update snapshot with debouncing and race condition prevention
  Future<void> _updateSnapshot({required bool isCelebration}) async {
    if (_pendingUpdate != null) {
      _skippedCount++;
      // Only log skipped updates occasionally to reduce noise
      final now = DateTime.now();
      if (_lastSkipLogTime == null || 
          now.difference(_lastSkipLogTime!) > const Duration(seconds: 2)) {
        if (_skippedCount > 1) {
          AppLogger.debug('Snapshot update skipped ($_skippedCount times)');
        }
        _lastSkipLogTime = now;
        _skippedCount = 0;
      }
      try {
        await _pendingUpdate;
      } catch (_) {}
      return;
    }
    _skippedCount = 0;
    _pendingUpdate = _performUpdate(isCelebration: isCelebration);
    try {
      await _pendingUpdate;
    } finally {
      _pendingUpdate = null;
    }
  }

  /// Perform the actual snapshot update
  Future<void> _performUpdate({required bool isCelebration}) async {
    if (_isUpdating) {
      return;
    }

    _isUpdating = true;
    try {
      final currentSnapshot = await _snapshotService.getSnapshot();
      final snapshot = await _snapshotService.generateSnapshot(
        currentMascotState: currentSnapshot?.mascot,
        isCelebration: isCelebration,
      );

      // Wait for SharedPreferences to flush before notifying widget
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetNotifier.notifyWidgetUpdate();

      // Track celebration expiry for next transition calculation
      // Check snapshot state, not input flag, since celebration can persist across updates
      final now = DateTime.now();
      if (snapshot.mascot.emotion == MascotEmotion.celebrate &&
          snapshot.mascot.expiresAt != null &&
          snapshot.mascot.expiresAt!.isAfter(now)) {
        _celebrationExpiresAt = snapshot.mascot.expiresAt;
      } else {
        _celebrationExpiresAt = null;
      }

      // Schedule next time-based transition (in-app timer)
      _scheduleNextTransition();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update widget snapshot', e, stackTrace);
    } finally {
      _isUpdating = false;
    }
  }

  /// Schedule timer for the next state transition
  void _scheduleNextTransition() {
    _nextTransitionTimer?.cancel();

    final now = DateTime.now();
    final nextTime = _calculateNextTransition(now);
    final delay = nextTime.difference(now);

    if (delay > Duration.zero) {
      _nextTransitionTimer = Timer(delay, () {
        _nextTransitionTimer = null;
        _updateSnapshot(isCelebration: false);
      });
      AppLogger.debug('Widget refresh scheduled for $nextTime');
    }
  }

  /// Calculate the next time widget state might change
  DateTime _calculateNextTransition(DateTime now) {
    final candidates = <DateTime>[];

    // Next 30-min interval for CTA rotation
    final nextHalfHour = DateTime(
      now.year, now.month, now.day, now.hour,
      now.minute < 30 ? 30 : 0,
    ).add(now.minute >= 30 ? const Duration(hours: 1) : Duration.zero);
    candidates.add(nextHalfHour);

    // Celebration expiry
    if (_celebrationExpiresAt != null && _celebrationExpiresAt!.isAfter(now)) {
      candidates.add(_celebrationExpiresAt!);
    }

    // State transition hours (build list for today and tomorrow)
    final transitionHours = [
      AppConstants.endOfDayEndHour,    // 5:00 - end of bedtime
      ...AppConstants.longTermFocusHours, // 14:00, 20:00 - long-term start
      ...AppConstants.longTermFocusHours.map((h) => h + 1), // 15:00, 21:00 - long-term end
      AppConstants.endOfDayStartHour,  // 23:00 - bedtime start
    ];

    for (final hour in transitionHours) {
      var candidate = DateTime(now.year, now.month, now.day, hour);
      if (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      candidates.add(candidate);
    }

    // Return the earliest upcoming transition
    candidates.sort();
    return candidates.first;
  }

  /// Cancel all timers (for cleanup)
  void dispose() {
    _nextTransitionTimer?.cancel();
    _debounceTimer?.cancel();
  }
}
