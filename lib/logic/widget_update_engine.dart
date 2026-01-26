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
    _goalRepository.setChangeListener(_handleGoalChange);
  }

  /// Handle goal change events from repository
  Future<void> _handleGoalChange({
    required String event,
    required Goal? goal,
    required String? goalId,
    required bool isCelebration,
  }) async {
    await _updateSnapshot(isCelebration: isCelebration);
  }

  /// Internal method to update snapshot with debouncing
  Future<void> _updateSnapshot({required bool isCelebration}) async {
    if (_isUpdating) {
      AppLogger.debug('Snapshot update already in progress, skipping');
      return;
    }

    _isUpdating = true;
    try {
      final currentSnapshot = await _snapshotService.getSnapshot();
      await _snapshotService.generateSnapshot(
        currentMascotState: currentSnapshot?.mascot,
        isCelebration: isCelebration,
      );

      // Wait for SharedPreferences to flush before notifying widget
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetNotifier.notifyWidgetUpdate();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update widget snapshot', e, stackTrace);
    } finally {
      _isUpdating = false;
    }
  }

  /// Force update snapshot (useful for manual refresh)
  Future<void> forceUpdate({bool isCelebration = false}) async {
    await _updateSnapshot(isCelebration: isCelebration);
  }
}
