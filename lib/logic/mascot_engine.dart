import '../domain/goal.dart';
import '../domain/mascot_state.dart';
import 'urgency_engine.dart';
import '../utils/constants.dart';

/// Maps urgency and context to mascot emotion
class MascotEngine {
  /// Determine mascot emotion from urgency score
  static MascotEmotion emotionFromUrgency(double urgency) {
    if (urgency < AppConstants.urgencyHappy) {
      return MascotEmotion.happy; // Ahead of schedule
    } else if (urgency < AppConstants.urgencyNeutral) {
      return MascotEmotion.neutral; // On track
    } else if (urgency < AppConstants.urgencyWorried) {
      return MascotEmotion.worried; // Behind schedule
    } else {
      return MascotEmotion.sad; // Missed or critical
    }
  }

  /// Compute mascot state for a goal
  static MascotState computeState(
    Goal goal,
    DateTime now,
    MascotState? currentState,
  ) {
    // Check if we should revert from celebrate
    if (currentState != null) {
      final resolved =
          currentState.resolve(now, _getDefaultEmotion(goal, now));
      if (resolved.emotion != currentState.emotion) {
        return resolved;
      }
      // Still in celebrate state
      if (currentState.emotion == MascotEmotion.celebrate) {
        return currentState;
      }
    }

    // Compute default emotion from urgency
    final urgency = UrgencyEngine.calculateUrgency(goal, now);
    final emotion = emotionFromUrgency(urgency);

    // Cycle frame index for animation effect
    final frameIndex =
        currentState != null ? ((currentState.frameIndex + 1) % 2) : 0;

    return MascotState(
      emotion: emotion,
      frameIndex: frameIndex,
    );
  }

  /// Create celebrate state (triggered after logging progress)
  static MascotState createCelebrateState(DateTime now) {
    return MascotState(
      emotion: MascotEmotion.celebrate,
      frameIndex: 0,
      expiresAt: now.add(AppConstants.celebrateDuration),
    );
  }

  /// Get default emotion for a goal (without celebrate)
  static MascotEmotion _getDefaultEmotion(Goal goal, DateTime now) {
    final urgency = UrgencyEngine.calculateUrgency(goal, now);
    return emotionFromUrgency(urgency);
  }
}
