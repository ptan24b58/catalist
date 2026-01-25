import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/goal.dart';
import 'domain/mascot_state.dart';
import 'logic/urgency_engine.dart';
import 'logic/mascot_engine.dart';
import 'data/goal_repository.dart';
import 'utils/constants.dart';
import 'utils/logger.dart';

/// Widget snapshot model
class WidgetSnapshot {
  final int version;
  final int generatedAt;
  final TopGoal? topGoal;
  final MascotState mascot;

  WidgetSnapshot({
    required this.version,
    required this.generatedAt,
    this.topGoal,
    required this.mascot,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'generatedAt': generatedAt,
      'topGoal': topGoal?.toJson(),
      'mascot': mascot.toJson(),
    };
  }

  factory WidgetSnapshot.fromJson(Map<String, dynamic> json) {
    return WidgetSnapshot(
      version: json['version'] as int,
      generatedAt: json['generatedAt'] as int,
      topGoal: json['topGoal'] != null
          ? TopGoal.fromJson(json['topGoal'] as Map<String, dynamic>)
          : null,
      mascot: MascotState.fromJson(json['mascot'] as Map<String, dynamic>),
    );
  }
}

/// Top goal for widget display
class TopGoal {
  final String id;
  final String title;
  final double progress;
  final String goalType; // 'daily' or 'longTerm'
  final String progressType; // 'completion', 'percentage', 'milestones', 'numeric'
  final int? nextDueEpoch;
  final double urgency;
  final String? progressLabel; // Human-readable progress (e.g., "3/5 milestones")

  TopGoal({
    required this.id,
    required this.title,
    required this.progress,
    required this.goalType,
    required this.progressType,
    this.nextDueEpoch,
    required this.urgency,
    this.progressLabel,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'progress': progress,
      'goalType': goalType,
      'progressType': progressType,
      'nextDueEpoch': nextDueEpoch,
      'urgency': urgency,
      'progressLabel': progressLabel,
    };
  }

  factory TopGoal.fromJson(Map<String, dynamic> json) {
    return TopGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      progress: (json['progress'] as num).toDouble(),
      goalType: json['goalType'] as String,
      progressType: json['progressType'] as String,
      nextDueEpoch: json['nextDueEpoch'] as int?,
      urgency: (json['urgency'] as num).toDouble(),
      progressLabel: json['progressLabel'] as String?,
    );
  }
}

/// Service for generating and storing widget snapshots
class WidgetSnapshotService {
  static const String _snapshotKey = 'widget_snapshot';
  final GoalRepository _goalRepository = GoalRepository();

  /// Generate and save a new snapshot
  Future<WidgetSnapshot> generateSnapshot({
    MascotState? currentMascotState,
    bool isCelebration = false,
  }) async {
    final now = DateTime.now();
    final goals = await _goalRepository.getAllGoals();

    if (goals.isEmpty) {
      // No goals - neutral mascot
      const mascot = MascotState(emotion: MascotEmotion.neutral);
      final snapshot = WidgetSnapshot(
        version: AppConstants.snapshotVersion,
        generatedAt: now.millisecondsSinceEpoch ~/ 1000,
        mascot: mascot,
      );
      await _saveSnapshot(snapshot);
      return snapshot;
    }

    // Find most urgent goal
    final mostUrgentGoal = UrgencyEngine.findMostUrgent(goals, now);

    if (mostUrgentGoal == null) {
      const mascot = MascotState(emotion: MascotEmotion.neutral);
      final snapshot = WidgetSnapshot(
        version: AppConstants.snapshotVersion,
        generatedAt: now.millisecondsSinceEpoch ~/ 1000,
        mascot: mascot,
      );
      await _saveSnapshot(snapshot);
      return snapshot;
    }

    final maxUrgency = UrgencyEngine.calculateUrgency(mostUrgentGoal, now);

    // Compute mascot state
    MascotState mascot;
    if (isCelebration) {
      mascot = MascotEngine.createCelebrateState(now);
    } else {
      mascot = MascotEngine.computeState(
        mostUrgentGoal,
        now,
        currentMascotState,
      );
    }

    // Create top goal data
    final progress = mostUrgentGoal.getProgress();
    final nextDue = mostUrgentGoal.getNextDueTime(now);
    final topGoal = TopGoal(
      id: mostUrgentGoal.id,
      title: mostUrgentGoal.title,
      progress: progress,
      goalType: mostUrgentGoal.goalType.name,
      progressType: mostUrgentGoal.progressType.name,
      nextDueEpoch: nextDue != null ? (nextDue.millisecondsSinceEpoch ~/ 1000) : null,
      urgency: maxUrgency,
      progressLabel: _getProgressLabel(mostUrgentGoal),
    );

    final snapshot = WidgetSnapshot(
      version: AppConstants.snapshotVersion,
      generatedAt: now.millisecondsSinceEpoch ~/ 1000,
      topGoal: topGoal,
      mascot: mascot,
    );

    await _saveSnapshot(snapshot);
    return snapshot;
  }

  /// Get human-readable progress label
  String _getProgressLabel(Goal goal) {
    switch (goal.progressType) {
      case ProgressType.completion:
        return goal.isCompleted ? 'Done' : 'Not done';
      case ProgressType.percentage:
        return '${goal.percentComplete.toInt()}%';
      case ProgressType.milestones:
        return '${goal.completedMilestones}/${goal.milestones.length}';
      case ProgressType.numeric:
        final unit = goal.unit ?? '';
        return '${goal.currentValue.toStringAsFixed(0)}/${goal.targetValue?.toStringAsFixed(0) ?? '?'} $unit'.trim();
    }
  }

  /// Get the current snapshot
  Future<WidgetSnapshot?> getSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshotJson = prefs.getString(_snapshotKey);

      if (snapshotJson == null) {
        return null;
      }

      final decoded = jsonDecode(snapshotJson) as Map<String, dynamic>;
      return WidgetSnapshot.fromJson(decoded);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load widget snapshot', e, stackTrace);
      return null;
    }
  }

  /// Save snapshot to shared storage
  Future<void> _saveSnapshot(WidgetSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(snapshot.toJson());
      await prefs.setString(_snapshotKey, encoded);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save widget snapshot', e, stackTrace);
      rethrow;
    }
  }

  /// Get snapshot as JSON string (for native widgets)
  Future<String?> getSnapshotJson() async {
    final snapshot = await getSnapshot();
    if (snapshot == null) return null;
    return jsonEncode(snapshot.toJson());
  }
}
