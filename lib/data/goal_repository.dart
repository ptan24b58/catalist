import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/goal.dart';
import '../services/widget_updater.dart';
import '../services/goal_image_service.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../utils/id_generator.dart';
import '../utils/validation.dart';
import '../utils/gamification.dart';

/// Callback signature for goal change events
typedef GoalChangeCallback = Future<void> Function({
  required String event,
  required Goal? goal,
  required String? goalId,
  required bool isCelebration,
});

/// Repository for managing goals
class GoalRepository {
  static const String _goalsKey = 'goals';
  static const String _lifetimeXpKey = 'lifetime_earned_xp';
  static const String _perfectDayStreakKey = 'perfect_day_streak';
  static const String _lastPerfectDayKey = 'last_perfect_day';
  static const String _perfectDaysHistoryKey = 'perfect_days_history';

  GoalChangeCallback? _changeListener;

  /// Set a listener to be notified when goals change
  void setChangeListener(GoalChangeCallback? listener) {
    _changeListener = listener;
  }

  /// Notify listener of a goal change
  Future<void> _notifyChange({
    required String event,
    Goal? goal,
    String? goalId,
    bool isCelebration = false,
  }) async {
    if (_changeListener != null) {
      await _changeListener!(
        event: event,
        goal: goal,
        goalId: goalId,
        isCelebration: isCelebration,
      );
    }
  }

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
      
      // Find the goal to delete and clean up its image if present
      final goalToDelete = goals.where((g) => g.id == id).firstOrNull;
      if (goalToDelete?.completionImagePath != null) {
        await GoalImageService().deleteImage(goalToDelete!.completionImagePath);
      }
      
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

  /// Get all dates where all daily goals were completed (perfect days history).
  /// Returns a Set of normalized DateTime objects (midnight UTC).
  Future<Set<DateTime>> getPerfectDaysHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_perfectDaysHistoryKey);
      
      if (historyJson == null || historyJson.isEmpty) {
        return {};
      }
      
      final decoded = jsonDecode(historyJson);
      if (decoded is! List) {
        return {};
      }
      
      return decoded
          .map((e) => DateTime.tryParse(e as String))
          .whereType<DateTime>()
          .map((d) => DateUtils.normalizeToDay(d))
          .toSet();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get perfect days history', e, stackTrace);
      return {};
    }
  }

  /// Add a date to perfect days history
  Future<void> _addPerfectDayToHistory(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getPerfectDaysHistory();
      final normalizedDate = DateUtils.normalizeToDay(date);
      
      if (history.contains(normalizedDate)) {
        return; // Already recorded
      }
      
      history.add(normalizedDate);
      
      // Keep only last 365 days to prevent unbounded growth
      final cutoff = DateTime.now().subtract(const Duration(days: 365));
      final filtered = history.where((d) => d.isAfter(cutoff)).toList();
      
      final encoded = jsonEncode(filtered.map((d) => d.toIso8601String()).toList());
      await prefs.setString(_perfectDaysHistoryKey, encoded);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add perfect day to history', e, stackTrace);
    }
  }

  /// Get the perfect day streak (consecutive days where ALL daily goals were completed).
  /// This value is persistent and doesn't change when goals are added/deleted.
  /// It resets only when a day passes without completing all daily goals.
  Future<int> getPerfectDayStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streak = prefs.getInt(_perfectDayStreakKey) ?? 0;
      final lastPerfectDayStr = prefs.getString(_lastPerfectDayKey);
      
      if (streak == 0 || lastPerfectDayStr == null) {
        return 0;
      }
      
      // Check if the streak is still valid (last perfect day was today or yesterday)
      final lastPerfectDay = DateTime.tryParse(lastPerfectDayStr);
      if (lastPerfectDay == null) {
        return 0;
      }
      
      final today = DateUtils.normalizeToDay(DateTime.now());
      final yesterday = DateUtils.getYesterday(DateTime.now());
      final normalizedLastPerfect = DateUtils.normalizeToDay(lastPerfectDay);
      
      // If last perfect day was today or yesterday, streak is valid
      if (normalizedLastPerfect == today || normalizedLastPerfect == yesterday) {
        return streak;
      }
      
      // Streak broken - reset it
      await prefs.setInt(_perfectDayStreakKey, 0);
      await prefs.remove(_lastPerfectDayKey);
      return 0;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get perfect day streak', e, stackTrace);
      return 0;
    }
  }

  /// Check if all daily goals are completed for today and update the perfect day streak.
  /// Called internally after logging daily goal completion.
  Future<void> _checkAndUpdatePerfectDayStreak(DateTime now) async {
    try {
      final goals = await getAllGoals();
      final dailyGoals = goals.where((g) => g.goalType == GoalType.daily).toList();
      
      // No daily goals = no perfect day streak to track
      if (dailyGoals.isEmpty) {
        return;
      }
      
      // Check if ALL daily goals are completed today
      final today = DateUtils.normalizeToDay(now);
      final allCompletedToday = dailyGoals.every((goal) {
        if (goal.lastCompletedAt == null) return false;
        return DateUtils.normalizeToDay(goal.lastCompletedAt!) == today;
      });
      
      if (!allCompletedToday) {
        return; // Not all goals done yet, don't update streak
      }
      
      // All goals completed today! Update the perfect day streak.
      final prefs = await SharedPreferences.getInstance();
      final currentStreak = prefs.getInt(_perfectDayStreakKey) ?? 0;
      final lastPerfectDayStr = prefs.getString(_lastPerfectDayKey);
      
      // Check if we already counted today as a perfect day
      if (lastPerfectDayStr != null) {
        final lastPerfectDay = DateTime.tryParse(lastPerfectDayStr);
        if (lastPerfectDay != null && DateUtils.normalizeToDay(lastPerfectDay) == today) {
          return; // Already counted today
        }
      }
      
      // Determine new streak value
      int newStreak;
      if (lastPerfectDayStr == null) {
        // First perfect day ever
        newStreak = 1;
      } else {
        final lastPerfectDay = DateTime.tryParse(lastPerfectDayStr);
        final yesterday = DateUtils.getYesterday(now);
        
        if (lastPerfectDay != null && DateUtils.normalizeToDay(lastPerfectDay) == yesterday) {
          // Continuing streak from yesterday
          newStreak = currentStreak + 1;
        } else {
          // Streak was broken, start fresh
          newStreak = 1;
        }
      }
      
      await prefs.setInt(_perfectDayStreakKey, newStreak);
      await prefs.setString(_lastPerfectDayKey, today.toIso8601String());
      
      // Also add to perfect days history for calendar display
      await _addPerfectDayToHistory(today);
      
      AppLogger.info('Perfect day streak updated: $newStreak');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update perfect day streak', e, stackTrace);
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

    // Determine if goal was already completed before this action
    final wasCompletedBefore = goal.progressType == ProgressType.numeric
        ? (goal.targetValue != null && todayCompletions.length >= goal.targetValue!)
        : (lastCompleted == today);

    // Add new completion
    todayCompletions.add(completedAt);

    // Determine if goal is now completed after this action
    final isCompletedAfter = goal.progressType == ProgressType.numeric
        ? (goal.targetValue != null && todayCompletions.length >= goal.targetValue!)
        : true; // For completion type, any completion = done

    // Update streak logic
    // For completion goals: bump on first completion today.
    // For numeric goals: only bump when goal transitions to completed today.
    //
    // For numeric goals, we defer lastCompletedAt until the target is met
    // so that _calculateNewStreak can see the true pre-today date.
    final shouldUpdateStreak = goal.progressType == ProgressType.numeric
        ? (!wasCompletedBefore && isCompletedAfter)
        : true;

    final newStreak = shouldUpdateStreak
        ? _calculateNewStreak(goal.currentStreak, lastCompleted, today, yesterday)
        : goal.currentStreak;

    // For numeric goals, only set lastCompletedAt when the goal completes
    // (or was already completed). This preserves the pre-today date for
    // accurate streak calculation on the completing call.
    final shouldSetLastCompleted = goal.progressType == ProgressType.numeric
        ? (isCompletedAfter || wasCompletedBefore)
        : true;

    final updatedGoal = goal.copyWith(
      lastCompletedAt: shouldSetLastCompleted ? completedAt : goal.lastCompletedAt,
      todayCompletions: todayCompletions,
      currentStreak: newStreak,
      longestStreak:
          newStreak > goal.longestStreak ? newStreak : goal.longestStreak,
    );

    // Only award XP when goal transitions from incomplete → complete
    // For numeric: only when target is first reached today
    // For completion: only on first completion of the day
    if (!wasCompletedBefore && isCompletedAfter) {
      await addLifetimeXp(Gamification.xpPerDailyCompletion);
    }
    await saveGoal(updatedGoal);
    
    // Check if all daily goals are now completed → update perfect day streak
    await _checkAndUpdatePerfectDayStreak(completedAt);

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

  Future<void> _saveAllGoals(List<Goal> goals, {Goal? changedGoal, String event = 'save', bool isCelebration = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(goals.map((g) => g.toJson()).toList());
      await prefs.setString(_goalsKey, encoded);
      // Trigger native widget refresh so CTA reflects the new state
      WidgetUpdater.update();
      // Notify change listener
      await _notifyChange(
        event: event,
        goal: changedGoal,
        goalId: changedGoal?.id,
        isCelebration: isCelebration,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save goals to storage', e, stackTrace);
      rethrow;
    }
  }
}
