import '../domain/goal.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

/// Calculates urgency score (0-1) for a goal
class UrgencyEngine {
  /// Calculate urgency based on goal type and progress
  static double calculateUrgency(Goal goal, DateTime now) {
    if (goal.isCompleted) {
      return 0.0; // Completed goals have no urgency
    }

    if (goal.goalType == GoalType.daily) {
      return _calculateDailyUrgency(goal, now);
    } else {
      return _calculateLongTermUrgency(goal, now);
    }
  }

  /// Calculate urgency for daily goals
  static double _calculateDailyUrgency(Goal goal, DateTime now) {
    final progress = goal.getProgressToday(now);
    final nextDue = goal.getNextDueTime(now);

    if (nextDue == null) {
      return 0.0;
    }

    // Progress component (0-0.5 weight)
    double progressScore = 0.0;
    if (goal.progressType == ProgressType.completion) {
      progressScore = (progress < 1.0) ? AppConstants.progressWeight : 0.0;
    } else if (goal.progressType == ProgressType.numeric) {
      // Numeric: how far behind daily target?
      final target = goal.dailyTarget;
      final progressRatio = progress / target;
      progressScore = (1.0 - progressRatio.clamp(0.0, 1.0)) * AppConstants.progressWeight;
    }

    // Time component (0-0.4 weight)
    final timeRemaining = nextDue.difference(now);
    final totalTimeWindow = _getDailyTimeWindow(now);
    double timeScore = 0.0;
    if (totalTimeWindow > Duration.zero) {
      final timeRatio = timeRemaining.inSeconds / totalTimeWindow.inSeconds;
      timeScore = (1.0 - timeRatio.clamp(0.0, 1.0)) * AppConstants.timeWeight;
    }

    // Streak risk component (0-0.1 weight)
    double streakScore = 0.0;
    if (goal.currentStreak > 0) {
      final yesterday = DateUtils.getYesterday(now);
      final lastCompleted = goal.lastCompletedAt;
      if (lastCompleted == null ||
          DateUtils.normalizeToDay(lastCompleted).isBefore(yesterday)) {
        streakScore = AppConstants.streakWeight;
      }
    }

    return (progressScore + timeScore + streakScore).clamp(0.0, 1.0);
  }

  /// Calculate urgency for long-term goals based on deadline and progress
  static double _calculateLongTermUrgency(Goal goal, DateTime now) {
    final progress = goal.getProgress();
    final deadline = goal.deadline;

    // No deadline = lower urgency, just based on progress stagnation
    if (deadline == null) {
      // Simple: urgency is inverse of progress (less done = more urgent)
      // But cap at 0.5 since no deadline means less pressure
      return ((1.0 - progress) * 0.5).clamp(0.0, 0.5);
    }

    // Check if overdue
    if (goal.isOverdue(now)) {
      return 1.0; // Maximum urgency for overdue goals
    }

    // Deadline-based urgency calculation
    final daysRemaining = goal.getDaysRemaining(now) ?? 0;
    final totalDays = deadline.difference(goal.createdAt).inDays;

    // Avoid division by zero
    if (totalDays <= 0) {
      return 1.0;
    }

    // Calculate expected progress based on time elapsed
    final daysElapsed = totalDays - daysRemaining;
    final expectedProgress = daysElapsed / totalDays;
    final actualProgress = progress;

    // Progress deficit: how far behind schedule
    final progressDeficit = (expectedProgress - actualProgress).clamp(0.0, 1.0);

    // Time pressure: urgency increases as deadline approaches
    final timePressure = 1.0 - (daysRemaining / totalDays).clamp(0.0, 1.0);

    // Weighted combination
    final deadlineScore = timePressure * AppConstants.deadlineWeight;
    final progressScore = progressDeficit * AppConstants.longTermProgressWeight;

    return (deadlineScore + progressScore).clamp(0.0, 1.0);
  }

  /// Get the time window for daily goals (full day)
  static Duration _getDailyTimeWindow(DateTime now) =>
      const Duration(days: 1);

  /// Find the most urgent goal from a list
  static Goal? findMostUrgent(List<Goal> goals, DateTime now) {
    if (goals.isEmpty) return null;

    Goal? mostUrgent;
    double highestUrgency = -1;

    for (final goal in goals) {
      if (goal.isCompleted) continue;

      final urgency = calculateUrgency(goal, now);
      if (urgency > highestUrgency) {
        highestUrgency = urgency;
        mostUrgent = goal;
      }
    }

    return mostUrgent;
  }

  /// Get urgency level as a category
  static UrgencyLevel getUrgencyLevel(double urgency) {
    if (urgency < AppConstants.urgencyHappy) {
      return UrgencyLevel.low;
    } else if (urgency < AppConstants.urgencyNeutral) {
      return UrgencyLevel.medium;
    } else if (urgency < AppConstants.urgencyWorried) {
      return UrgencyLevel.high;
    } else {
      return UrgencyLevel.critical;
    }
  }
}

/// Urgency levels for UI display
enum UrgencyLevel {
  low,      // < 0.2 - On track
  medium,   // 0.2-0.5 - Normal
  high,     // 0.5-0.8 - Behind
  critical, // > 0.8 - Urgent/overdue
}
