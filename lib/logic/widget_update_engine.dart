import '../data/goal_repository.dart';
import '../domain/goal.dart';
import '../services/widget_snapshot_service.dart';
import '../services/widget_notifier.dart';
import '../utils/logger.dart';

/// Engine that automatically updates widget snapshots when goals change
/// 
/// This engine listens to goal repository changes and automatically
/// regenerates the widget snapshot to keep it in sync with the current
/// state of goals.
class WidgetUpdateEngine {
  final GoalRepository _goalRepository;
  final WidgetSnapshotService _snapshotService;
  bool _isUpdating = false;

  WidgetUpdateEngine(this._goalRepository, this._snapshotService) {
    // Register as listener for goal changes
    _goalRepository.setChangeListener(_handleGoalChange);
    print('🔧 [WIDGET] WidgetUpdateEngine initialized and listening for changes');
  }

  /// Handle goal change events from repository
  Future<void> _handleGoalChange({
    required String event,
    required Goal? goal,
    required String? goalId,
    required bool isCelebration,
  }) async {
    print('🔄 [WIDGET] Goal change detected: $event (goalId: ${goalId ?? goal?.id ?? 'unknown'})');
    await _updateSnapshot(
      reason: event,
      goalId: goalId ?? goal?.id ?? '',
      isCelebration: isCelebration,
    );
  }

  /// Update snapshot after a goal is added (manual trigger if needed)
  Future<void> onGoalAdded(Goal goal) async {
    await _updateSnapshot(
      reason: 'goal_added',
      goalId: goal.id,
      isCelebration: false,
    );
  }

  /// Update snapshot after a goal is updated (manual trigger if needed)
  Future<void> onGoalUpdated(Goal goal, {bool isCelebration = false}) async {
    await _updateSnapshot(
      reason: 'goal_updated',
      goalId: goal.id,
      isCelebration: isCelebration,
    );
  }

  /// Update snapshot after a goal is deleted (manual trigger if needed)
  Future<void> onGoalDeleted(String goalId) async {
    await _updateSnapshot(
      reason: 'goal_deleted',
      goalId: goalId,
      isCelebration: false,
    );
  }

  /// Update snapshot after progress is logged (manual trigger if needed)
  Future<void> onProgressLogged(Goal goal, {bool isCelebration = true}) async {
    await _updateSnapshot(
      reason: 'progress_logged',
      goalId: goal.id,
      isCelebration: isCelebration,
    );
  }

  /// Internal method to update snapshot with debouncing
  Future<void> _updateSnapshot({
    required String reason,
    required String goalId,
    required bool isCelebration,
  }) async {
    // Prevent concurrent updates
    if (_isUpdating) {
      AppLogger.debug('Snapshot update already in progress, skipping $reason');
      return;
    }

    _isUpdating = true;
    try {
      // Get current mascot state to preserve celebration state
      final currentSnapshot = await _snapshotService.getSnapshot();
      final currentMascotState = currentSnapshot?.mascot;

      print('🔄 [WIDGET] Generating snapshot: $reason (goal: $goalId, celebration: $isCelebration)');
      await _snapshotService.generateSnapshot(
        currentMascotState: currentMascotState,
        isCelebration: isCelebration,
      );

      print('✅ [WIDGET] Widget snapshot updated: $reason (goal: $goalId)');
      
      // Wait longer to ensure SharedPreferences write is flushed to disk
      // SharedPreferences uses apply() which is async, so we need to wait
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Notify native widget to refresh
      await WidgetNotifier.notifyWidgetUpdate();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update widget snapshot', e, stackTrace);
    } finally {
      _isUpdating = false;
    }
  }

  /// Force update snapshot (useful for manual refresh)
  Future<void> forceUpdate({bool isCelebration = false}) async {
    await _updateSnapshot(
      reason: 'manual_refresh',
      goalId: '',
      isCelebration: isCelebration,
    );
  }
}
