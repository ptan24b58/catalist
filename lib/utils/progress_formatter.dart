import '../domain/goal.dart';

/// Centralized progress label formatting to avoid duplication
class ProgressFormatter {
  ProgressFormatter._(); // Private constructor

  /// Get human-readable progress label for a goal
  static String getProgressLabel(Goal goal, {DateTime? now}) {
    switch (goal.progressType) {
      case ProgressType.completion:
        return goal.isCompleted ? 'Done' : 'Not done';
      case ProgressType.percentage:
        return '${goal.percentComplete.toInt()}%';
      case ProgressType.milestones:
        return '${goal.completedMilestones}/${goal.milestones.length}';
      case ProgressType.numeric:
        return _formatNumericProgress(goal, now: now);
    }
  }

  /// Get detailed progress label for list views
  static String getDetailedProgressLabel(Goal goal, {DateTime? now}) {
    switch (goal.progressType) {
      case ProgressType.completion:
        return goal.isCompleted ? 'Completed' : 'Not completed';
      case ProgressType.percentage:
        return '${goal.percentComplete.toInt()}%';
      case ProgressType.milestones:
        return '${goal.completedMilestones}/${goal.milestones.length} milestones';
      case ProgressType.numeric:
        return _formatDetailedNumericProgress(goal, now: now);
    }
  }

  static String _formatNumericProgress(Goal goal, {DateTime? now}) {
    final unit = goal.unit ?? '';
    return '${goal.currentValue.toStringAsFixed(0)}/${goal.targetValue?.toStringAsFixed(0) ?? '?'} $unit'
        .trim();
  }

  static String _formatDetailedNumericProgress(Goal goal, {DateTime? now}) {
    final unit = goal.unit ?? '';
    if (goal.goalType == GoalType.daily && now != null) {
      final todayProgress = goal.getProgressToday(now).toInt();
      return '$todayProgress/${goal.dailyTarget} $unit today';
    }
    return '${goal.currentValue.toStringAsFixed(0)}/${goal.targetValue?.toStringAsFixed(0) ?? '?'} $unit';
  }
}
