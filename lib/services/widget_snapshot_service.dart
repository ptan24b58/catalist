import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/goal.dart';
import '../domain/mascot_state.dart';
import '../logic/urgency_engine.dart';
import '../logic/mascot_engine.dart';
import '../logic/cta_engine.dart';
import '../data/goal_repository.dart';
import '../models/widget_snapshot.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/progress_formatter.dart';
import '../utils/widget_background_theme.dart';

/// Generates widget snapshots following CTA_engine.txt flow:
/// 1. empty → 2. 5-min celebration → 3. end of day (11pm-5am) → 4. long-term focus (14:00, 20:00) → 5. all daily complete → 6. daily in-progress
class WidgetSnapshotService {
  static const String _snapshotKey = 'widget_snapshot';
  final GoalRepository _goalRepository;

  WidgetSnapshotService(this._goalRepository);

  static const _fiveMin = Duration(minutes: 5);

  Future<WidgetSnapshot> generateSnapshot({
    MascotState? currentMascotState,
    bool isCelebration = false,
  }) async {
    final now = DateTime.now();
    final goals = await _goalRepository.getAllGoals();

    // 1. Empty state
    if (goals.isEmpty) {
      return _buildSnapshot(now: now, context: CTAContext.empty);
    }

    final dailyGoals = goals.where((g) => g.goalType == GoalType.daily).toList();
    final longTermGoals = goals.where((g) => g.goalType == GoalType.longTerm).toList();
    final incompleteDailies = dailyGoals.where((g) => !g.isCompleted).toList();
    final incompleteLongTerm = longTermGoals.where((g) => !g.isCompleted).toList();

    // 2. 5-min celebration for any recently completed goal (highest priority)
    final recentlyCompleted = _findRecentlyCompleted(goals, now);
    if (recentlyCompleted != null) {
      final ctaContext = recentlyCompleted.goalType == GoalType.daily
          ? CTAContext.dailyCompletedOne5Min
          : CTAContext.longTermCompleted5Min;
      return _buildSnapshot(
        now: now,
        context: ctaContext,
        goal: recentlyCompleted,
        mascot: MascotEngine.createCelebrateState(now),
        status: WidgetBackgroundStatus.celebrate,
      );
    }

    // 3. End of day (11pm to 5am)
    if (_isEndOfDay(now)) {
      final mostUrgent = UrgencyEngine.findMostUrgent(goals, now);
      return _buildSnapshot(
        now: now,
        context: CTAContext.endOfDay,
        goal: mostUrgent,
        mascot: const MascotState(emotion: MascotEmotion.neutral),
        status: WidgetBackgroundStatus.endOfDay,
      );
    }

    // 4. Long-term focus hour (14:00, 20:00)
    if (_isLongTermHour(now) && incompleteLongTerm.isNotEmpty) {
      final mostUrgent = UrgencyEngine.findMostUrgent(incompleteLongTerm, now) ?? incompleteLongTerm.first;
      final urgency = UrgencyEngine.calculateUrgency(mostUrgent, now);
      return _buildSnapshot(
        now: now,
        context: CTAContext.longTermInProgress,
        goal: mostUrgent,
        mascot: MascotEngine.computeState(mostUrgent, now, currentMascotState),
        status: _statusFromUrgency(urgency),
      );
    }

    // 5. All daily goals complete
    if (dailyGoals.isNotEmpty && incompleteDailies.isEmpty) {
      final lastCompleted = _findMostRecentlyCompleted(dailyGoals);
      return _buildSnapshot(
        now: now,
        context: CTAContext.dailyAllComplete,
        goal: lastCompleted,
        mascot: MascotEngine.createCelebrateState(now),
        status: WidgetBackgroundStatus.celebrate,
      );
    }

    // 6. Daily in progress (or fallback to long-term if no dailies)
    final targetGoals = incompleteDailies.isNotEmpty ? incompleteDailies : incompleteLongTerm;
    if (targetGoals.isEmpty) {
      return _buildSnapshot(now: now, context: CTAContext.empty);
    }

    final mostUrgent = UrgencyEngine.findMostUrgent(targetGoals, now) ?? targetGoals.first;
    final urgency = UrgencyEngine.calculateUrgency(mostUrgent, now);
    final ctaContext = mostUrgent.goalType == GoalType.daily
        ? CTAContext.dailyInProgress
        : CTAContext.longTermInProgress;

    return _buildSnapshot(
      now: now,
      context: ctaContext,
      goal: mostUrgent,
      mascot: isCelebration
          ? MascotEngine.createCelebrateState(now)
          : MascotEngine.computeState(mostUrgent, now, currentMascotState),
      status: isCelebration ? WidgetBackgroundStatus.celebrate : _statusFromUrgency(urgency),
      progressLabel: ctaContext == CTAContext.dailyInProgress
          ? ProgressFormatter.getProgressLabel(mostUrgent, now: now)
          : null,
    );
  }

  /// Find the most recently completed goal within 5 minutes
  Goal? _findRecentlyCompleted(List<Goal> goals, DateTime now) {
    Goal? recent;
    DateTime? recentTime;
    for (final g in goals) {
      final completedAt = g.lastCompletedAt;
      if (g.isCompleted && completedAt != null && now.difference(completedAt) < _fiveMin) {
        if (recentTime == null || completedAt.isAfter(recentTime)) {
          recent = g;
          recentTime = completedAt;
        }
      }
    }
    return recent;
  }

  /// Find the most recently completed goal from a list
  Goal? _findMostRecentlyCompleted(List<Goal> goals) {
    Goal? recent;
    DateTime? recentTime;
    for (final g in goals) {
      final completedAt = g.lastCompletedAt ?? g.createdAt;
      if (g.isCompleted) {
        if (recentTime == null || completedAt.isAfter(recentTime)) {
          recent = g;
          recentTime = completedAt;
        }
      }
    }
    return recent;
  }

  bool _isEndOfDay(DateTime now) =>
      now.hour >= AppConstants.endOfDayStartHour || now.hour < AppConstants.endOfDayEndHour;

  bool _isLongTermHour(DateTime now) =>
      AppConstants.longTermFocusHours.contains(now.hour);

  WidgetBackgroundStatus _statusFromUrgency(double urgency) {
    if (urgency >= AppConstants.urgencyWorried) return WidgetBackgroundStatus.urgent;
    if (urgency >= AppConstants.urgencyHappy) return WidgetBackgroundStatus.behind;
    return WidgetBackgroundStatus.onTrack;
  }

  /// Unified snapshot builder with sensible defaults
  Future<WidgetSnapshot> _buildSnapshot({
    required DateTime now,
    required CTAContext context,
    Goal? goal,
    MascotState? mascot,
    WidgetBackgroundStatus? status,
    String? progressLabel,
  }) async {
    final effectiveStatus = status ?? WidgetBackgroundStatus.empty;
    final effectiveMascot = mascot ?? const MascotState(emotion: MascotEmotion.neutral);
    final urgency = goal != null ? UrgencyEngine.calculateUrgency(goal, now) : 0.0;

    TopGoal? topGoal;
    if (goal != null) {
      final nextDue = goal.getNextDueTime(now);
      topGoal = TopGoal(
        id: goal.id,
        title: goal.title,
        progress: goal.getProgress(),
        goalType: goal.goalType.name,
        progressType: goal.progressType.name,
        nextDueEpoch: nextDue != null ? (nextDue.millisecondsSinceEpoch ~/ 1000) : null,
        urgency: urgency,
        progressLabel: ProgressFormatter.getProgressLabel(goal, now: now),
      );
    }

    final cta = CTAEngine.generateFromContext(context, now, progressLabel);
    final statusName = WidgetBackgroundTheme.statusName(effectiveStatus);
    final timeBand = WidgetBackgroundTheme.getTimeBand(now);
    final variant = WidgetBackgroundTheme.getVariant(now, statusName);

    final snapshot = WidgetSnapshot(
      version: AppConstants.snapshotVersion,
      generatedAt: now.millisecondsSinceEpoch ~/ 1000,
      topGoal: topGoal,
      mascot: effectiveMascot,
      cta: cta,
      backgroundStatus: statusName,
      backgroundTimeBand: WidgetBackgroundTheme.timeBandName(timeBand),
      backgroundVariant: variant,
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  Future<WidgetSnapshot?> getSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshotJson = prefs.getString(_snapshotKey);
      if (snapshotJson == null) return null;
      return WidgetSnapshot.fromJson(jsonDecode(snapshotJson) as Map<String, dynamic>);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load widget snapshot', e, stackTrace);
      return null;
    }
  }

  Future<void> _saveSnapshot(WidgetSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save widget snapshot', e, stackTrace);
      rethrow;
    }
  }

  Future<String?> getSnapshotJson() async {
    final s = await getSnapshot();
    return s != null ? jsonEncode(s.toJson()) : null;
  }
}
