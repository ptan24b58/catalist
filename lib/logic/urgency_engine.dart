import '../domain/goal.dart';
import '../utils/constants.dart';

/// Engine for calculating goal urgency scores.
/// 
/// Urgency is a 0-1 score where:
/// - 0.0 = no urgency (on track, plenty of time)
/// - 0.2 = happy threshold (doing well)
/// - 0.5 = neutral (needs attention soon)
/// - 0.8 = worried threshold (falling behind)
/// - 1.0 = maximum urgency (critical/overdue)
class UrgencyEngine {
  UrgencyEngine._(); // Static-only class

  /// Calculate urgency score for a goal (0-1)
  static double calculateUrgency(Goal goal, DateTime now) {
    if (goal.isCompleted) return 0.0;

    switch (goal.goalType) {
      case GoalType.daily:
        return _calculateDailyUrgency(goal, now);
      case GoalType.longTerm:
        return _calculateLongTermUrgency(goal, now);
    }
  }

  /// Calculate urgency for daily goals based on:
  /// - Time of day (progress toward end of day)
  /// - Current progress
  /// - Streak at risk
  static double _calculateDailyUrgency(Goal goal, DateTime now) {
    // Time factor: how far through the day (5am to 11pm = active hours)
    final activeStart = DateTime(now.year, now.month, now.day, AppConstants.endOfDayEndHour);
    final activeEnd = DateTime(now.year, now.month, now.day, AppConstants.endOfDayStartHour);
    
    double timeFactor;
    if (now.isBefore(activeStart)) {
      timeFactor = 0.0; // Before 5am, no time pressure
    } else if (now.isAfter(activeEnd)) {
      timeFactor = 1.0; // After 11pm, maximum time pressure
    } else {
      final elapsed = now.difference(activeStart).inMinutes;
      final total = activeEnd.difference(activeStart).inMinutes;
      timeFactor = (elapsed / total).clamp(0.0, 1.0);
    }

    // Progress factor: inverse of progress (less progress = more urgent)
    final progress = goal.getProgressToday(now);
    final progressFactor = 1.0 - progress;

    // Streak factor: longer streak = more at risk = higher urgency if not done
    final streakFactor = goal.currentStreak > 0 && !goal.isCompleted
        ? (goal.currentStreak / 30).clamp(0.0, 0.5) // Cap at 0.5 for 30+ day streaks
        : 0.0;

    // Weighted combination
    return (
      AppConstants.progressWeight * progressFactor +
      AppConstants.timeWeight * timeFactor +
      AppConstants.streakWeight * streakFactor
    ).clamp(0.0, 1.0);
  }

  /// Calculate urgency for long-term goals based on:
  /// - Time remaining until deadline
  /// - Current progress
  static double _calculateLongTermUrgency(Goal goal, DateTime now) {
    final progress = goal.getProgress();

    // No deadline: urgency based purely on progress (low urgency)
    if (goal.deadline == null) {
      // Goals without deadline have low base urgency
      return ((1.0 - progress) * 0.3).clamp(0.0, 0.3);
    }

    // Overdue: maximum urgency
    if (goal.isOverdue(now)) {
      return 1.0;
    }

    // Calculate deadline factor
    final totalDuration = goal.deadline!.difference(goal.createdAt).inHours;
    final remaining = goal.deadline!.difference(now).inHours;
    
    double deadlineFactor;
    if (totalDuration <= 0) {
      deadlineFactor = 1.0;
    } else {
      // Time elapsed as a fraction
      final elapsed = (totalDuration - remaining) / totalDuration;
      deadlineFactor = elapsed.clamp(0.0, 1.0);
    }

    // Expected progress vs actual progress
    final expectedProgress = deadlineFactor;
    final progressGap = (expectedProgress - progress).clamp(0.0, 1.0);

    // Weighted combination
    return (
      AppConstants.deadlineWeight * deadlineFactor +
      AppConstants.longTermProgressWeight * progressGap
    ).clamp(0.0, 1.0);
  }

  /// Find the most urgent incomplete goal from a list
  static Goal? findMostUrgent(List<Goal> goals, DateTime now) {
    final incompleteGoals = goals.where((g) => !g.isCompleted).toList();
    if (incompleteGoals.isEmpty) return null;

    Goal mostUrgent = incompleteGoals.first;
    double highestUrgency = calculateUrgency(mostUrgent, now);

    for (final goal in incompleteGoals.skip(1)) {
      final urgency = calculateUrgency(goal, now);
      if (urgency > highestUrgency) {
        highestUrgency = urgency;
        mostUrgent = goal;
      }
    }

    return mostUrgent;
  }

  /// Get urgency level as a string for display
  static String getUrgencyLevel(double urgency) {
    if (urgency >= AppConstants.urgencyWorried) return 'high';
    if (urgency >= AppConstants.urgencyNeutral) return 'medium';
    if (urgency >= AppConstants.urgencyHappy) return 'low';
    return 'none';
  }
}
