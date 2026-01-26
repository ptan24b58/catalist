import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/goal.dart';
import '../domain/mascot_state.dart';
import '../logic/urgency_engine.dart';
import '../logic/mascot_engine.dart';
import '../data/goal_repository.dart';
import '../models/widget_snapshot.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/progress_formatter.dart';

/// Service for generating and storing widget snapshots
class WidgetSnapshotService {
  static const String _snapshotKey = 'widget_snapshot';
  final GoalRepository _goalRepository;

  WidgetSnapshotService(this._goalRepository);

  /// Generate and save a new snapshot
  Future<WidgetSnapshot> generateSnapshot({
    MascotState? currentMascotState,
    bool isCelebration = false,
  }) async {
    final now = DateTime.now();
    final goals = await _goalRepository.getAllGoals();

    if (goals.isEmpty) {
      return _createEmptySnapshot(now);
    }

    // Find most urgent goal
    final mostUrgentGoal = UrgencyEngine.findMostUrgent(goals, now);

    if (mostUrgentGoal == null) {
      return _createEmptySnapshot(now);
    }

    final maxUrgency = UrgencyEngine.calculateUrgency(mostUrgentGoal, now);

    // Compute mascot state
    final mascot = isCelebration
        ? MascotEngine.createCelebrateState(now)
        : MascotEngine.computeState(mostUrgentGoal, now, currentMascotState);

    // Create top goal data
    final topGoal = _createTopGoal(mostUrgentGoal, maxUrgency, now);

    final snapshot = WidgetSnapshot(
      version: AppConstants.snapshotVersion,
      generatedAt: now.millisecondsSinceEpoch ~/ 1000,
      topGoal: topGoal,
      mascot: mascot,
    );

    await _saveSnapshot(snapshot);
    return snapshot;
  }

  /// Create empty snapshot when no goals exist
  Future<WidgetSnapshot> _createEmptySnapshot(DateTime now) async {
    final snapshot = WidgetSnapshot(
      version: AppConstants.snapshotVersion,
      generatedAt: now.millisecondsSinceEpoch ~/ 1000,
      mascot: const MascotState(emotion: MascotEmotion.neutral),
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  /// Create TopGoal from Goal model
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
      final success = await prefs.setString(_snapshotKey, encoded);
      
      // Log the JSON snapshot for debugging
      print('📦 [WIDGET] Widget snapshot saved (success: $success):');
      print('📦 [WIDGET] JSON: $encoded');
      
      // Wait a bit for SharedPreferences to flush to disk
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify it was saved and wait for it to be readable
      int retries = 0;
      String? verify;
      while (retries < 5) {
        verify = prefs.getString(_snapshotKey);
        if (verify == encoded) {
          print('✅ [WIDGET] Snapshot verified in SharedPreferences (attempt ${retries + 1})');
          break;
        }
        retries++;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      if (verify != encoded) {
        print('⚠️ [WIDGET] Snapshot verification failed after $retries retries!');
        print('⚠️ [WIDGET] Expected: ${encoded.substring(0, encoded.length > 100 ? 100 : encoded.length)}...');
        print('⚠️ [WIDGET] Got: ${verify?.substring(0, (verify?.length ?? 0) > 100 ? 100 : (verify?.length ?? 0))}...');
      }
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
