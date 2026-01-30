import '../domain/goal.dart';
import '../domain/mascot_state.dart';
import '../utils/constants.dart';
import 'urgency_engine.dart';

/// Engine for determining mascot emotional state based on goal progress
class MascotEngine {
  MascotEngine._(); // Static-only class

  /// Compute mascot state based on goal urgency
  static MascotState computeState(Goal goal, DateTime now, MascotState? currentState) {
    // If currently celebrating and not expired, continue celebrating
    if (currentState != null &&
        currentState.emotion == MascotEmotion.celebrate &&
        !currentState.isExpired(now)) {
      return currentState;
    }

    final urgency = UrgencyEngine.calculateUrgency(goal, now);
    final emotion = _emotionFromUrgency(urgency, goal.isCompleted);

    return MascotState(emotion: emotion);
  }

  /// Create a celebration state (e.g., when goal is completed)
  static MascotState createCelebrateState(DateTime now) {
    return MascotState.celebrate(now);
  }

  /// Determine emotion based on urgency score
  static MascotEmotion _emotionFromUrgency(double urgency, bool isCompleted) {
    if (isCompleted) return MascotEmotion.happy;
    
    if (urgency >= AppConstants.urgencyWorried) {
      return MascotEmotion.worried;
    } else if (urgency >= AppConstants.urgencyNeutral) {
      return MascotEmotion.neutral;
    } else {
      return MascotEmotion.happy;
    }
  }

  /// Get emotion for overall state (multiple goals)
  static MascotState computeOverallState(List<Goal> goals, DateTime now, MascotState? currentState) {
    // If currently celebrating and not expired, continue celebrating
    if (currentState != null &&
        currentState.emotion == MascotEmotion.celebrate &&
        !currentState.isExpired(now)) {
      return currentState;
    }

    if (goals.isEmpty) {
      return const MascotState(emotion: MascotEmotion.neutral);
    }

    // Find the most urgent goal and base emotion on that
    final mostUrgent = UrgencyEngine.findMostUrgent(goals, now);
    if (mostUrgent == null) {
      // All goals completed
      return const MascotState(emotion: MascotEmotion.happy);
    }

    return computeState(mostUrgent, now, currentState);
  }

  /// Get display message for emotion
  static String getEmotionMessage(MascotEmotion emotion) {
    return AppConstants.getEmotionMessage(emotion.name);
  }
}
