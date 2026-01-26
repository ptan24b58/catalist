import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/goal.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../utils/id_generator.dart';

/// Callback type for goal change events
typedef GoalChangeCallback = Future<void> Function({
  required String event,
  required Goal? goal,
  required String? goalId,
  required bool isCelebration,
});

/// Repository for managing goals
class GoalRepository {
  static const String _goalsKey = 'goals';
  GoalChangeCallback? _onGoalChanged;

  /// Register a callback to be notified when goals change
  void setChangeListener(GoalChangeCallback? callback) {
    _onGoalChanged = callback;
  }

  /// Notify listeners of a goal change
  Future<void> _notifyChange({
    required String event,
    required Goal? goal,
    required String? goalId,
    required bool isCelebration,
  }) async {
    if (_onGoalChanged != null) {
      try {
        await _onGoalChanged!(
          event: event,
          goal: goal,
          goalId: goalId,
          isCelebration: isCelebration,
        );
      } catch (e, stackTrace) {
        AppLogger.error('Error in goal change callback', e, stackTrace);
      }
    }
  }

  /// Helper to notify progress logged with completion check
  Future<void> _notifyProgressLogged(Goal goal, bool isCompleted) async {
    await _notifyChange(
      event: 'progress_logged',
      goal: goal,
      goalId: goal.id,
      isCelebration: isCompleted,
    );
  }

  /// Get all goals
  Future<List<Goal>> getAllGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = prefs.getString(_goalsKey);

      if (goalsJson == null) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(goalsJson) as List<dynamic>;
      return decoded
          .map((json) {
            try {
              return Goal.fromJson(json as Map<String, dynamic>);
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

      // Notify listeners
      await _notifyChange(
        event: isNew ? 'goal_added' : 'goal_updated',
        goal: goal,
        goalId: goal.id,
        isCelebration: false,
      );
    } catch (e, stackTrace) {
      AppLogger.error(AppConstants.errorSaveFailed, e, stackTrace);
      rethrow;
    }
  }

  /// Delete a goal
  Future<void> deleteGoal(String id) async {
    if (id.isEmpty) throw ArgumentError('Goal ID cannot be empty');
    try {
      final goals = await getAllGoals();
      goals.removeWhere((g) => g.id == id);
      await _saveAllGoals(goals);

      // Notify listeners
      await _notifyChange(
        event: 'goal_deleted',
        goal: null,
        goalId: id,
        isCelebration: false,
      );
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

  /// Helper to get and validate goal
  Future<Goal> _getGoalOrThrow(String goalId) async {
    if (goalId.isEmpty) throw ArgumentError('Goal ID cannot be empty');
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

    // Update streak logic
    int newStreak = goal.currentStreak;
    bool isFirstCompletionToday = lastCompleted != today;

    if (isFirstCompletionToday) {
      if (lastCompleted == null) {
        // First completion ever
        newStreak = 1;
      } else if (lastCompleted == yesterday) {
        // Continuing streak
        newStreak = goal.currentStreak + 1;
      } else {
        // Streak broken, start new
        newStreak = 1;
      }
    }

    final updatedGoal = goal.copyWith(
      lastCompletedAt: completedAt,
      todayCompletions: todayCompletions,
      currentStreak: newStreak,
      longestStreak:
          newStreak > goal.longestStreak ? newStreak : goal.longestStreak,
    );

    await saveGoal(updatedGoal);

    // Notify listeners of progress logged
    await _notifyChange(
      event: 'progress_logged',
      goal: updatedGoal,
      goalId: updatedGoal.id,
      isCelebration: true,
    );

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
      final updatedGoal = goal.copyWith(
        currentValue: newValue,
        lastCompletedAt: completedAt,
      );
      await saveGoal(updatedGoal);
      await _notifyProgressLogged(updatedGoal, goal.targetValue != null && newValue >= goal.targetValue!);
      return updatedGoal;
    }
  }

  /// Update numeric progress (set absolute value) for long-term goals
  Future<Goal> updateNumericProgress(String goalId, double newValue) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.numeric) {
      throw Exception('Goal is not a numeric progress type');
    }

    final updatedGoal = goal.copyWith(
      currentValue: newValue,
      lastCompletedAt: DateTime.now(),
    );

      await saveGoal(updatedGoal);
      await _notifyProgressLogged(updatedGoal, goal.targetValue != null && newValue >= goal.targetValue!);
      return updatedGoal;
  }

  /// Update percentage progress for long-term goals
  Future<Goal> updatePercentage(String goalId, double newPercent) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.percentage) {
      throw Exception('Goal is not a percentage progress type');
    }

    final clampedPercent = newPercent.clamp(0.0, 100.0);
    final updatedGoal = goal.copyWith(
      percentComplete: clampedPercent,
      lastCompletedAt: DateTime.now(),
    );

    await saveGoal(updatedGoal);
    await _notifyProgressLogged(updatedGoal, clampedPercent >= 100);
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

    await saveGoal(updatedGoal);
    await _notifyProgressLogged(updatedGoal, updatedMilestones.every((m) => m.completed));
    return updatedGoal;
  }

  /// Add a new milestone to a goal
  Future<Goal> addMilestone(String goalId, String milestoneTitle) async {
    final goal = await _getGoalOrThrow(goalId);
    if (goal.progressType != ProgressType.milestones) {
      throw Exception('Goal is not a milestone progress type');
    }

    final newMilestone = Milestone(
      id: IdGenerator.generate(),
      title: milestoneTitle,
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

    // Notify listeners
    await _notifyChange(
      event: 'goal_updated',
      goal: updatedGoal,
      goalId: updatedGoal.id,
      isCelebration: false,
    );

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

    await saveGoal(updatedGoal);
    await _notifyProgressLogged(updatedGoal, true);
    return updatedGoal;
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
