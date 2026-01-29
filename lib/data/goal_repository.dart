import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/goal.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../utils/id_generator.dart';
import '../utils/validation.dart';
import '../utils/gamification.dart';

/// Repository for managing goals
class GoalRepository {
  static const String _goalsKey = 'goals';
  static const String _lifetimeXpKey = 'lifetime_earned_xp';

  /// Get all goals
  Future<List<Goal>> getAllGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = prefs.getString(_goalsKey);

      if (goalsJson == null || goalsJson.isEmpty) {
        return [];
      }

      // Validate JSON size to prevent DoS
      if (goalsJson.length > 1000000) { // 1MB limit
        AppLogger.error('Goals JSON too large, potential corruption');
        return [];
      }

      final decoded = jsonDecode(goalsJson);
      if (decoded is! List) {
        AppLogger.error('Invalid goals format: expected List');
        return [];
      }

      return decoded
          .map((json) {
            try {
              if (json is! Map<String, dynamic>) {
                AppLogger.warning('Invalid goal format: expected Map');
                return null;
              }
              return Goal.fromJson(json);
            } catch (e, stackTrace) {
              AppLogger.warning('Failed to parse goal from JSON', e);
              AppLogger.debug('Invalid goal JSON: $json', e, stackTrace);
              return null;
            }
          })
          .whereType<Goal>()
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(AppConstants.errorLoadFailed, e, stackTrace);
      return [];
    }
  }

  /// Get all daily goals
  Future<List<Goal>> getDailyGoals() async {
    final goals = await getAllGoals();
    return goals.where((g) => g.goalType == GoalType.daily).toList();
  }

  /// Get all long-term goals
  Future<List<Goal>> getLongTermGoals() async {
    final goals = await getAllGoals();
    return goals.where((g) => g.goalType == GoalType.longTerm).toList();
  }

  /// Save a goal
  Future<void> saveGoal(Goal goal) async {
    try {
      final goals = await getAllGoals();
      final index = goals.indexWhere((g) => g.id == goal.id);
      final isNew = index < 0;

      if (index >= 0) {
        goals[index] = goal;
      } else {
        goals.add(goal);
      }

      await _saveAllGoals(goals);
    } catch (e, stackTrace) {
      AppLogger.error(AppConstants.errorSaveFailed, e, stackTrace);
      rethrow;
    }
  }

  /// Delete a goal
  Future<void> deleteGoal(String id) async {
    if (id.isEmpty || !Validation.isValidGoalId(id)) {
      throw ArgumentError('Invalid goal ID');
    }
    try {
      final goals = await getAllGoals();
      goals.removeWhere((g) => g.id == id);
      await _saveAllGoals(goals);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete goal', e, stackTrace);
      rethrow;
    }
  }

  /// Get a goal by ID
  Future<Goal?> getGoalById(String id) async {
    final goals = await getAllGoals();
    try {
      return goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lifetime earned XP (never decreases; only increases when goals are completed).
  /// Migrates from goal-derived XP on first read if key is missing.
  Future<int> getLifetimeEarnedXp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_lifetimeXpKey)) {
        return prefs.getInt(_lifetimeXpKey) ?? 0;
      }
      final goals = await getAllGoals();
      final migrated = (Gamification.calculateTotalXP(goals)).clamp(0, 0x7FFFFFFF);
      await prefs.setInt(_lifetimeXpKey, migrated);
      return migrated;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get lifetime XP', e, stackTrace);
      return 0;
    }
  }

  /// Add XP to lifetime total (called when a goal is completed). Never subtract.
  Future<void> addLifetimeXp(int amount) async {
    if (amount <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_lifetimeXpKey) ?? 0;
      await prefs.setInt(_lifetimeXpKey, (current + amount).clamp(0, 0x7FFFFFFF));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add lifetime XP', e, stackTrace);
    }
  }

  /// Helper to get and validate goal
  Future<Goal> _getGoalOrThrow(String goalId) async {
    if (goalId.isEmpty || !Validation.isValidGoalId(goalId)) {
      throw ArgumentError('Invalid goal ID');
    }
    final goal = await getGoalById(goalId);
    if (goal == null) throw Exception(AppConstants.errorGoalNotFound);
    return goal;
  }

  /// Log progress for a daily completion goal
  Future<Goal> logDailyCompletion(String goalId, DateTime completedAt) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.goalType != GoalType.daily) {
      throw Exception('Cannot log daily completion for long-term goal');
    }

    final today = DateUtils.normalizeToDay(completedAt);
    final yesterday = DateUtils.getYesterday(completedAt);
    final lastCompleted = goal.lastCompletedAt != null
        ? DateUtils.normalizeToDay(goal.lastCompletedAt!)
        : null;

    // Clean up old completions (keep only today's)
    final todayCompletions = goal.todayCompletions
        .where((c) => DateUtils.isSameDay(c, completedAt))
        .toList();

    // Add new completion
    todayCompletions.add(completedAt);

    // Update streak logic - only if this is the first completion today
    final newStreak = _calculateNewStreak(
      goal.currentStreak,
      lastCompleted,
      today,
      yesterday,
    );

    final updatedGoal = goal.copyWith(
      lastCompletedAt: completedAt,
      todayCompletions: todayCompletions,
      currentStreak: newStreak,
      longestStreak:
          newStreak > goal.longestStreak ? newStreak : goal.longestStreak,
    );

    await addLifetimeXp(Gamification.xpPerDailyCompletion);
    await saveGoal(updatedGoal);

    return updatedGoal;
  }

  /// Log numeric progress for daily numeric goals
  Future<Goal> logDailyNumericProgress(
      String goalId, double amount, DateTime completedAt) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.numeric) {
      throw Exception('Goal is not a numeric progress type');
    }

    if (goal.goalType == GoalType.daily) {
      // For daily numeric goals, track completions and streaks
      return await logDailyCompletion(goalId, completedAt);
    } else {
      // For long-term numeric goals, add to current value
      final newValue = goal.currentValue + amount;
      final justCompleted = goal.targetValue != null && newValue >= goal.targetValue!;
      if (!goal.isCompleted && justCompleted) {
        await addLifetimeXp(Gamification.xpPerGoalCompleted);
      }
      final updatedGoal = goal.copyWith(
        currentValue: newValue,
        lastCompletedAt: completedAt,
      );
      await saveGoal(updatedGoal);
      return updatedGoal;
    }
  }

  /// Update numeric progress (set absolute value) for long-term goals
  Future<Goal> updateNumericProgress(String goalId, double newValue) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.numeric) {
      throw Exception('Goal is not a numeric progress type');
    }

    final justCompleted = goal.targetValue != null && newValue >= goal.targetValue!;
    if (!goal.isCompleted && justCompleted) {
      await addLifetimeXp(Gamification.xpPerGoalCompleted);
    }
    final updatedGoal = goal.copyWith(
      currentValue: newValue,
      lastCompletedAt: DateTime.now(),
    );

    await saveGoal(updatedGoal);
    return updatedGoal;
  }

  /// Update percentage progress for long-term goals
  Future<Goal> updatePercentage(String goalId, double newPercent) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.percentage) {
      throw Exception('Goal is not a percentage progress type');
    }

    final clampedPercent = newPercent.clamp(0.0, 100.0);
    final justCompleted = clampedPercent >= 100;
    if (!goal.isCompleted && justCompleted) {
      await addLifetimeXp(Gamification.xpPerGoalCompleted);
    }
    final updatedGoal = goal.copyWith(
      percentComplete: clampedPercent,
      lastCompletedAt: DateTime.now(),
    );

    await saveGoal(updatedGoal);
    return updatedGoal;
  }

  /// Toggle milestone completion
  Future<Goal> toggleMilestone(String goalId, String milestoneId) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.milestones) {
      throw Exception('Goal is not a milestone progress type');
    }

    final milestoneIndex =
        goal.milestones.indexWhere((m) => m.id == milestoneId);
    if (milestoneIndex < 0) {
      throw Exception('Milestone not found');
    }

    final milestone = goal.milestones[milestoneIndex];
    final updatedMilestones = List<Milestone>.from(goal.milestones);

    updatedMilestones[milestoneIndex] = milestone.copyWith(
      completed: !milestone.completed,
      completedAt: !milestone.completed ? DateTime.now() : null,
    );

    final updatedGoal = goal.copyWith(
      milestones: updatedMilestones,
      lastCompletedAt: DateTime.now(),
    );

    final justCompleted = updatedMilestones.every((m) => m.completed);
    if (!goal.isCompleted && justCompleted) {
      await addLifetimeXp(Gamification.xpPerGoalCompleted);
    }
    await saveGoal(updatedGoal);
    return updatedGoal;
  }

  /// Add a new milestone to a goal
  Future<Goal> addMilestone(String goalId, String milestoneTitle) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.milestones) {
      throw Exception('Goal is not a milestone progress type');
    }

    // Validate and sanitize milestone title
    final sanitized = Validation.sanitizeMilestoneTitle(milestoneTitle);
    if (sanitized == null) {
      throw ArgumentError('Invalid milestone title');
    }
    
    // Check milestone limit
    if (goal.milestones.length >= AppConstants.maxMilestones) {
      throw Exception('Maximum ${AppConstants.maxMilestones} milestones allowed');
    }

    final newMilestone = Milestone(
      id: IdGenerator.generate(),
      title: sanitized,
    );

    final updatedMilestones = List<Milestone>.from(goal.milestones)
      ..add(newMilestone);

    final updatedGoal = goal.copyWith(milestones: updatedMilestones);

    await saveGoal(updatedGoal);
    return updatedGoal;
  }

  /// Remove a milestone from a goal
  Future<Goal> removeMilestone(String goalId, String milestoneId) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.milestones) {
      throw Exception('Goal is not a milestone progress type');
    }

    final updatedMilestones = goal.milestones
        .where((m) => m.id != milestoneId)
        .toList();

    final updatedGoal = goal.copyWith(milestones: updatedMilestones);

    await saveGoal(updatedGoal);
    return updatedGoal;
  }

  /// Mark a long-term completion goal as complete
  Future<Goal> markLongTermComplete(String goalId) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.goalType != GoalType.longTerm) {
      throw Exception('Goal is not a long-term goal');
    }

    Goal updatedGoal;
    switch (goal.progressType) {
      case ProgressType.completion:
        updatedGoal = goal.copyWith(lastCompletedAt: DateTime.now());
        break;
      case ProgressType.percentage:
        updatedGoal = goal.copyWith(
          percentComplete: 100,
          lastCompletedAt: DateTime.now(),
        );
        break;
      case ProgressType.numeric:
        updatedGoal = goal.copyWith(
          currentValue: goal.targetValue ?? goal.currentValue,
          lastCompletedAt: DateTime.now(),
        );
        break;
      case ProgressType.milestones:
        final completedMilestones = goal.milestones
            .map((m) => m.copyWith(
                  completed: true,
                  completedAt: m.completedAt ?? DateTime.now(),
                ))
            .toList();
        updatedGoal = goal.copyWith(
          milestones: completedMilestones,
          lastCompletedAt: DateTime.now(),
        );
        break;
    }

    if (!goal.isCompleted) {
      await addLifetimeXp(Gamification.xpPerGoalCompleted);
    }
    await saveGoal(updatedGoal);
    return updatedGoal;
  }

  /// Calculate new streak value based on completion history
  int _calculateNewStreak(
    int currentStreak,
    DateTime? lastCompleted,
    DateTime today,
    DateTime yesterday,
  ) {
    // If already completed today, don't change streak
    if (lastCompleted == today) {
      return currentStreak;
    }

    // First completion ever
    if (lastCompleted == null) {
      return 1;
    }

    // Continuing streak (completed yesterday)
    if (DateUtils.normalizeToDay(lastCompleted) == yesterday) {
      return currentStreak + 1;
    }

    // Streak broken, start new
    return 1;
  }

  Future<void> _saveAllGoals(List<Goal> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(goals.map((g) => g.toJson()).toList());
      await prefs.setString(_goalsKey, encoded);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save goals to storage', e, stackTrace);
      rethrow;
    }
  }
}
