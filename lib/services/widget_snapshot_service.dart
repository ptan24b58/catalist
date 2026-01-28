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
/// empty → daily focus (completed-one 5min | all-daily-done | in-progress) → long-term focus (hour slots) → end of day (11pm+).
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

    if (goals.isEmpty) {
      return _emptySnapshot(now);
    }

    final dailyGoals = goals.where((g) => g.goalType == GoalType.daily).toList();
    final longTermGoals = goals.where((g) => g.goalType == GoalType.longTerm).toList();
    final allDailyComplete = dailyGoals.isNotEmpty && dailyGoals.every((g) => g.isCompleted);
    final inLongTermHour = AppConstants.longTermFocusHours.contains(now.hour);

    // Just completed any goal < 5 min ago → celebration for 5 min (even past 11pm)
    final completed = goals.where((g) => g.isCompleted).toList()
      ..sort((a, b) => (b.lastCompletedAt ?? b.createdAt).compareTo(a.lastCompletedAt ?? a.createdAt));
    if (completed.isNotEmpty) {
      final last = completed.first;
      final lastAt = last.lastCompletedAt;
      if (lastAt != null && now.difference(lastAt) < _fiveMin) {
        final ctaContext = last.goalType == GoalType.daily
            ? CTAContext.dailyCompletedOne5Min
            : CTAContext.longTermCompleted5Min;
        final urgency = UrgencyEngine.calculateUrgency(last, now);
        return _snapshotFor(
          now: now,
          context: ctaContext,
          topGoal: _createTopGoal(last, urgency, now),
          mascot: MascotEngine.createCelebrateState(now),
          status: WidgetBackgroundStatus.celebrate,
        );
      }
    }

    // End of day (11pm+)
    if (now.hour >= AppConstants.endOfDayStartHour) {
      return _snapshotFor(
        now: now,
        context: CTAContext.endOfDay,
        topGoal: () {
          final g = UrgencyEngine.findMostUrgent(goals, now);
          return g != null ? _createTopGoal(g, 0, now) : null;
        }(),
        mascot: const MascotState(emotion: MascotEmotion.neutral),
        status: WidgetBackgroundStatus.endOfDay,
      );
    }

    // All daily complete → celebration, completed-one 5min else all-daily CTA
    if (allDailyComplete) {
      final completedDaily = dailyGoals.toList()
        ..sort((a, b) => (b.lastCompletedAt ?? b.createdAt).compareTo(a.lastCompletedAt ?? a.createdAt));
      final last = completedDaily.first;
      final lastAt = last.lastCompletedAt;
      final context = (lastAt != null && now.difference(lastAt) < _fiveMin)
          ? CTAContext.dailyCompletedOne5Min
          : CTAContext.dailyAllComplete;
      final urgency = UrgencyEngine.calculateUrgency(last, now);
      return _snapshotFor(
        now: now,
        context: context,
        topGoal: _createTopGoal(last, urgency, now),
        mascot: MascotEngine.createCelebrateState(now),
        status: WidgetBackgroundStatus.celebrate,
      );
    }

    // Long-term focus hour, no dailies (or only long-term) → show long-term
    if (inLongTermHour && dailyGoals.isEmpty && longTermGoals.isNotEmpty) {
      final completed = longTermGoals.where((g) => g.isCompleted).toList()
        ..sort((a, b) => (b.lastCompletedAt ?? b.createdAt).compareTo(a.lastCompletedAt ?? a.createdAt));
      final mostUrgent = UrgencyEngine.findMostUrgent(longTermGoals, now);
      final lastCompleted = completed.isNotEmpty ? completed.first : null;
      final justCompleted = lastCompleted != null &&
          lastCompleted.lastCompletedAt != null &&
          now.difference(lastCompleted.lastCompletedAt!) < _fiveMin;
      final context = justCompleted ? CTAContext.longTermCompleted5Min : CTAContext.longTermInProgress;
      final goal = justCompleted ? lastCompleted : (mostUrgent ?? lastCompleted);
      if (goal == null) return _emptySnapshot(now);
      final urgency = UrgencyEngine.calculateUrgency(goal, now);
      return _snapshotFor(
        now: now,
        context: context,
        topGoal: _createTopGoal(goal, urgency, now),
        mascot: justCompleted ? MascotEngine.createCelebrateState(now) : MascotEngine.computeState(goal, now, currentMascotState),
        status: justCompleted ? WidgetBackgroundStatus.celebrate : _statusFromUrgency(urgency),
      );
    }

    // Daily focus: incomplete dailies, or dailies exist and we’re not in long-term hour
    final incompleteDailies = dailyGoals.where((g) => !g.isCompleted).toList();
    final completedDailies = dailyGoals.where((g) => g.isCompleted).toList()
      ..sort((a, b) => (b.lastCompletedAt ?? b.createdAt).compareTo(a.lastCompletedAt ?? a.createdAt));
    final lastCompletedDaily = completedDailies.isNotEmpty ? completedDailies.first : null;
    final justCompletedDaily = lastCompletedDaily != null &&
        lastCompletedDaily.lastCompletedAt != null &&
        now.difference(lastCompletedDaily.lastCompletedAt!) < _fiveMin;

    CTAContext ctaContext;
    Goal displayGoal;
    MascotState mascot;
    WidgetBackgroundStatus status;

    if (justCompletedDaily) {
      ctaContext = CTAContext.dailyCompletedOne5Min;
      displayGoal = lastCompletedDaily;
      mascot = MascotEngine.createCelebrateState(now);
      status = WidgetBackgroundStatus.celebrate;
    } else if (incompleteDailies.isNotEmpty) {
      ctaContext = CTAContext.dailyInProgress;
      displayGoal = UrgencyEngine.findMostUrgent(incompleteDailies, now) ?? incompleteDailies.first;
      mascot = isCelebration
          ? MascotEngine.createCelebrateState(now)
          : MascotEngine.computeState(displayGoal, now, currentMascotState);
      status = isCelebration ? WidgetBackgroundStatus.celebrate : _statusFromUrgency(UrgencyEngine.calculateUrgency(displayGoal, now));
    } else {
      // No incomplete dailies, not all complete → only long-term left; show daily focus with “add more” or show most urgent
      final fallback = UrgencyEngine.findMostUrgent(goals, now);
      if (fallback == null) return _emptySnapshot(now);
      ctaContext = fallback.goalType == GoalType.daily ? CTAContext.dailyInProgress : CTAContext.longTermInProgress;
      displayGoal = fallback;
      mascot = MascotEngine.computeState(fallback, now, currentMascotState);
      status = _statusFromUrgency(UrgencyEngine.calculateUrgency(fallback, now));
    }

    final urgency = UrgencyEngine.calculateUrgency(displayGoal, now);
    final progressLabel = ctaContext == CTAContext.dailyInProgress ? ProgressFormatter.getProgressLabel(displayGoal, now: now) : null;
    return _snapshotFor(
      now: now,
      context: ctaContext,
      topGoal: _createTopGoal(displayGoal, urgency, now),
      mascot: mascot,
      status: status,
      progressLabel: progressLabel,
    );
  }

  WidgetBackgroundStatus _statusFromUrgency(double urgency) {
    if (urgency >= AppConstants.urgencyWorried) return WidgetBackgroundStatus.urgent;
    if (urgency >= AppConstants.urgencyHappy) return WidgetBackgroundStatus.behind;
    return WidgetBackgroundStatus.onTrack;
  }

  Future<WidgetSnapshot> _snapshotFor({
    required DateTime now,
    required CTAContext context,
    required TopGoal? topGoal,
    required MascotState mascot,
    required WidgetBackgroundStatus status,
    String? progressLabel,
  }) async {
    final cta = CTAEngine.generateFromContext(context, now, progressLabel);
    final statusName = WidgetBackgroundTheme.statusName(status);
    final timeBand = WidgetBackgroundTheme.getTimeBand(now);
    final variant = WidgetBackgroundTheme.getVariant(now, statusName);
    final snapshot = WidgetSnapshot(
      version: AppConstants.snapshotVersion,
      generatedAt: now.millisecondsSinceEpoch ~/ 1000,
      topGoal: topGoal,
      mascot: mascot,
      cta: cta,
      backgroundStatus: statusName,
      backgroundTimeBand: WidgetBackgroundTheme.timeBandName(timeBand),
      backgroundVariant: variant,
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  Future<WidgetSnapshot> _emptySnapshot(DateTime now) async {
    final cta = CTAEngine.generateFromContext(CTAContext.empty, now);
    final timeBand = WidgetBackgroundTheme.getTimeBand(now);
    final variant = WidgetBackgroundTheme.getVariant(now, 'empty');
    final snapshot = WidgetSnapshot(
      version: AppConstants.snapshotVersion,
      generatedAt: now.millisecondsSinceEpoch ~/ 1000,
      mascot: const MascotState(emotion: MascotEmotion.neutral),
      cta: cta,
      backgroundStatus: WidgetBackgroundTheme.statusName(WidgetBackgroundStatus.empty),
      backgroundTimeBand: WidgetBackgroundTheme.timeBandName(timeBand),
      backgroundVariant: variant,
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  TopGoal _createTopGoal(Goal goal, double urgency, DateTime now) {
    final nextDue = goal.getNextDueTime(now);
    return TopGoal(
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
