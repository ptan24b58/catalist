import 'package:flutter/material.dart';
import '../domain/goal.dart';
import 'app_colors.dart';

/// Streak tier information for display
class StreakTier {
  final String name;
  final int flameCount;
  final Color color;
  final bool hasGlow;
  final bool hasSparkles;

  const StreakTier({
    required this.name,
    required this.flameCount,
    required this.color,
    required this.hasGlow,
    required this.hasSparkles,
  });
}

/// Gamification utilities for XP, levels, and achievements
class Gamification {
  Gamification._();

  // XP values
  static const int xpPerGoalCompleted = 20;
  static const int xpPerDailyCompletion = 10;
  static const int xpPerMilestone = 15;
  static const int xpPerStreakDay = 5;
  static const int xpPerLevel = 100;

  /// Calculate total XP from all goals
  static int calculateTotalXP(List<Goal> goals) {
    int total = 0;
    
    for (final goal in goals) {
      // Base XP for creating goal
      total += 5;
      
      // Daily goals
      if (goal.goalType == GoalType.daily) {
        // XP for streak
        total += goal.currentStreak * xpPerStreakDay;
        
        // XP for completions
        if (goal.isCompleted) {
          total += xpPerDailyCompletion;
        }
      }
      
      // Long-term goals
      if (goal.goalType == GoalType.longTerm) {
        // XP for progress
        if (goal.progressType == ProgressType.percentage) {
          total += (goal.percentComplete / 10).round() * 2;
        } else if (goal.progressType == ProgressType.milestones) {
          total += goal.completedMilestones * xpPerMilestone;
        } else if (goal.progressType == ProgressType.numeric) {
          final progress = goal.getProgress();
          total += (progress * 20).round();
        }
        
        // Bonus for completion
        if (goal.isCompleted) {
          total += xpPerGoalCompleted;
        }
      }
    }
    
    return total;
  }

  /// Calculate level from total XP
  static int calculateLevel(int totalXP) {
    if (totalXP < 0) return 1;
    return (totalXP / xpPerLevel).floor() + 1;
  }

  /// Calculate XP needed for next level
  static int xpForNextLevel(int currentLevel) {
    return currentLevel * xpPerLevel;
  }

  /// Calculate XP progress in current level
  static int xpInCurrentLevel(int totalXP) {
    if (totalXP < 0) return 0;
    final level = calculateLevel(totalXP);
    final xpForCurrentLevel = (level - 1) * xpPerLevel;
    return (totalXP - xpForCurrentLevel).clamp(0, xpPerLevel);
  }

  /// Get progress percentage to next level
  static double getLevelProgress(int totalXP) {
    final xpInLevel = xpInCurrentLevel(totalXP);
    const xpNeeded = xpPerLevel;
    return (xpInLevel / xpNeeded).clamp(0.0, 1.0);
  }

  /// Get color for streak badge based on tier
  static Color getStreakColor(int streak) {
    if (streak >= 30) return AppColors.streakPlatinum;
    if (streak >= 14) return AppColors.streakGold;
    if (streak >= 7) return AppColors.streakSilver;
    if (streak >= 1) return AppColors.streakBronze;
    return AppColors.textSecondary;
  }

  /// Get streak tier info for display
  static StreakTier getStreakTier(int streak) {
    if (streak >= 30) {
      return StreakTier(
        name: 'Legendary',
        flameCount: 4,
        color: AppColors.streakPlatinum,
        hasGlow: true,
        hasSparkles: true,
      );
    }
    if (streak >= 14) {
      return StreakTier(
        name: 'Epic',
        flameCount: 3,
        color: AppColors.streakGold,
        hasGlow: true,
        hasSparkles: false,
      );
    }
    if (streak >= 7) {
      return StreakTier(
        name: 'Hot',
        flameCount: 2,
        color: AppColors.streakSilver,
        hasGlow: true,
        hasSparkles: false,
      );
    }
    if (streak >= 1) {
      return StreakTier(
        name: 'Active',
        flameCount: 1,
        color: AppColors.streakBronze,
        hasGlow: streak >= 3,
        hasSparkles: false,
      );
    }
    return StreakTier(
      name: 'Start',
      flameCount: 0,
      color: AppColors.textSecondary,
      hasGlow: false,
      hasSparkles: false,
    );
  }

  /// Get streak badge text (minimalist - returns empty for clean UI)
  static String getStreakBadge(int streak) {
    // Return empty for minimalist design
    return '';
  }

  /// Get achievement badge for goal completion (minimalist - returns empty)
  static String getAchievementBadge(Goal goal) {
    // Return empty for minimalist design
    return '';
  }

  /// Get goal card color based on progress
  static Color getGoalCardColor(Goal goal) {
    final progress = goal.getProgress();
    if (goal.isCompleted) return AppColors.emotionHappy;
    if (progress >= 0.8) return AppColors.emotionHappy;
    if (progress >= 0.5) return AppColors.emotionNeutral;
    if (progress >= 0.2) return AppColors.emotionWorried;
    return AppColors.catCream;
  }
}
