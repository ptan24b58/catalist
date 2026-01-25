import '../domain/goal.dart';

/// Centralized progress label formatting
class ProgressFormatter {
  ProgressFormatter._();

  /// Get human-readable progress label for a goal
  static String getProgressLabel(Goal goal, {DateTime? now}) {
    return switch (goal.progressType) {
      ProgressType.completion => goal.isCompleted ? 'Done' : 'Not done',
      ProgressType.percentage => '${goal.percentComplete.toInt()}%',
      ProgressType.milestones =>
        '${goal.completedMilestones}/${goal.milestones.length}',
      ProgressType.numeric => _formatNumeric(goal, now, detailed: false),
    };
  }

  /// Get detailed progress label for list views
  static String getDetailedProgressLabel(Goal goal, {DateTime? now}) {
    return switch (goal.progressType) {
      ProgressType.completion => goal.isCompleted ? 'Completed' : 'Not completed',
      ProgressType.percentage => '${goal.percentComplete.toInt()}%',
      ProgressType.milestones =>
        '${goal.completedMilestones}/${goal.milestones.length} milestones',
      ProgressType.numeric => _formatNumeric(goal, now, detailed: true),
    };
  }

  static String _formatNumeric(Goal goal, DateTime? now, {required bool detailed}) {
    final unit = goal.unit ?? '';
    final current = goal.currentValue.toStringAsFixed(0);
    final target = goal.targetValue?.toStringAsFixed(0) ?? '?';

    if (detailed && goal.goalType == GoalType.daily && now != null) {
      final today = goal.getProgressToday(now).toInt();
      return '$today/${goal.dailyTarget} $unit today';
    }
    return '$current/$target $unit'.trim();
  }
}
