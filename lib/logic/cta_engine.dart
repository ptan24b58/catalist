import '../domain/mascot_state.dart';
import '../models/widget_snapshot.dart';
import 'urgency_engine.dart';
import 'cta_messages.dart';

/// Generates dynamic, personalized CTAs with Gen Z-focused messaging
/// 
/// Creates context-aware, engaging call-to-action messages that adapt to:
/// - Urgency level and progress state
/// - Time of day and context
/// - Goal type and completion status
/// - Mascot emotion and personality
class CTAEngine {
  /// Generate a personalized CTA for the widget
  /// Rotates messages frequently based on time and goal status
  static String generateCTA({
    required TopGoal? topGoal,
    required MascotState mascot,
    required DateTime now,
  }) {
    // Empty state - no goals
    if (topGoal == null) {
      return _getEmptyStateCTA(now);
    }

    final urgency = topGoal.urgency;
    final urgencyLevel = UrgencyEngine.getUrgencyLevel(urgency);
    final progress = topGoal.progress;
    final goalType = topGoal.goalType;
    final isCompleted = progress >= 1.0;

    // Completed goals
    if (isCompleted) {
      return _getCompletedCTA(now, goalType);
    }

    // Generate CTA based on urgency level, progress state, time, and mascot emotion
    return _generateContextualCTA(
      urgencyLevel: urgencyLevel,
      emotion: mascot.emotion,
      progress: progress,
      goalType: goalType,
      now: now,
      progressLabel: topGoal.progressLabel,
      goalTitle: topGoal.title,
    );
  }

  /// Get CTA for empty state (no goals)
  /// Rotates messages frequently based on time of day
  static String _getEmptyStateCTA(DateTime now) {
    final hour = now.hour;
    final messages = _getEmptyStateMessages(hour);
    return _selectRotatingMessage(messages, now);
  }

  /// Get empty state messages based on time of day
  static List<String> _getEmptyStateMessages(int hour) {
    if (hour >= 6 && hour < 12) {
      return CTAMessages.emptyStateMorning;
    } else if (hour >= 12 && hour < 18) {
      return CTAMessages.emptyStateAfternoon;
    } else if (hour >= 18 && hour < 22) {
      return CTAMessages.emptyStateEvening;
    } else {
      return CTAMessages.emptyStateNight;
    }
  }

  /// Get CTA for completed goals
  /// Rotates messages frequently to celebrate achievements
  static String _getCompletedCTA(DateTime now, String goalType) {
    final messages = List<String>.from(
      goalType == 'daily'
          ? CTAMessages.completedDaily
          : CTAMessages.completedLongTerm
    );
    return _selectRotatingMessage(messages, now);
  }

  /// Generate contextual CTA based on urgency, progress state, time, and emotion
  static String _generateContextualCTA({
    required UrgencyLevel urgencyLevel,
    required MascotEmotion emotion,
    required double progress,
    required String goalType,
    required DateTime now,
    String? progressLabel,
    String? goalTitle,
  }) {
    // Celebrate emotion gets special treatment
    if (emotion == MascotEmotion.celebrate) {
      final messages = List<String>.from(CTAMessages.celebrate);
      final shortTitle = _getShortTitle(goalTitle);
      if (shortTitle != null) {
        messages.addAll([
          "Keep crushing $shortTitle!",
          "You're on fire with $shortTitle!",
          "Don't stop on $shortTitle!",
          "Keep the momentum with $shortTitle!",
          "You're winning with $shortTitle!",
        ]);
      }
      return _selectRotatingMessage(messages, now);
    }

    // Combine urgency level with progress state and time for nuanced messaging
    switch (urgencyLevel) {
      case UrgencyLevel.low:
        return _getLowUrgencyCTA(emotion, progress, goalType, now, progressLabel, goalTitle);
      case UrgencyLevel.medium:
        return _getMediumUrgencyCTA(emotion, progress, goalType, now, progressLabel, goalTitle);
      case UrgencyLevel.high:
        return _getHighUrgencyCTA(emotion, progress, goalType, now, progressLabel, goalTitle);
      case UrgencyLevel.critical:
        return _getCriticalUrgencyCTA(emotion, progress, goalType, now, progressLabel, goalTitle);
    }
  }

  /// Low urgency - ahead of schedule or on track
  /// Messages adapt to progress state and time of day
  static String _getLowUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final shortTitle = _getShortTitle(goalTitle);
    final progressState = _getProgressState(progress);
    final timeContext = _getTimeContext(now.hour);
    final messages = <String>[];

    if (emotion == MascotEmotion.happy) {
      _addProgressMessages(messages, progressState, 
        CTAMessages.lowUrgencyHappyEarly,
        CTAMessages.lowUrgencyHappyMid,
        CTAMessages.lowUrgencyHappyNearComplete);
      
      _addTimeContextMessages(messages, timeContext,
        CTAMessages.lowUrgencyHappyMorning,
        null,
        CTAMessages.lowUrgencyHappyEvening,
        null);
      
      messages.addAll(CTAMessages.lowUrgencyHappyGeneral);
    } else {
      _addProgressMessages(messages, progressState,
        CTAMessages.lowUrgencyNeutralEarly,
        null,
        CTAMessages.lowUrgencyNeutralNearComplete);
      
      messages.addAll(CTAMessages.lowUrgencyNeutralGeneral);
    }

    _addContextualMessages(messages, shortTitle, progressLabel);
    return _selectRotatingMessage(messages, now);
  }

  /// Medium urgency - normal pace
  /// Messages adapt to progress state, time of day, and goal type
  static String _getMediumUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final timeContext = _getTimeContext(now.hour);
    final progressState = _getProgressState(progress);
    final shortTitle = _getShortTitle(goalTitle);
    final messages = <String>[];

    if (emotion == MascotEmotion.worried) {
      _addProgressMessages(messages, progressState,
        CTAMessages.mediumUrgencyWorriedEarly,
        null,
        CTAMessages.mediumUrgencyWorriedNearComplete);
      
      messages.addAll(CTAMessages.mediumUrgencyWorriedGeneral);
    } else {
      _addProgressMessages(messages, progressState,
        CTAMessages.mediumUrgencyDefaultEarly,
        null,
        CTAMessages.mediumUrgencyDefaultNearComplete);
      
      _addTimeContextMessages(messages, timeContext,
        CTAMessages.mediumUrgencyMorning,
        CTAMessages.mediumUrgencyAfternoon,
        CTAMessages.mediumUrgencyEvening,
        CTAMessages.mediumUrgencyNight);
      
      messages.addAll(CTAMessages.mediumUrgencyGeneral);
    }

    _addContextualMessages(messages, shortTitle, progressLabel, timeContext, UrgencyLevel.medium, progressState);
    return _selectRotatingMessage(messages, now);
  }

  /// High urgency - behind schedule
  /// Messages adapt to progress state and time remaining
  static String _getHighUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final shortTitle = _getShortTitle(goalTitle);
    final progressState = _getProgressState(progress);
    final messages = <String>[];

    if (emotion == MascotEmotion.worried || emotion == MascotEmotion.sad) {
      _addProgressMessages(messages, progressState,
        CTAMessages.highUrgencyWorriedEarly,
        null,
        CTAMessages.highUrgencyWorriedNearComplete);
      
      messages.addAll(CTAMessages.highUrgencyWorriedGeneral);
    } else {
      _addProgressMessages(messages, progressState,
        CTAMessages.highUrgencyDefaultEarly,
        null,
        CTAMessages.highUrgencyDefaultNearComplete);
      
      messages.addAll(CTAMessages.highUrgencyDefaultGeneral);
    }

    _addContextualMessages(messages, shortTitle, progressLabel, null, UrgencyLevel.high, progressState);
    return _selectRotatingMessage(messages, now);
  }

  /// Critical urgency - overdue or very behind
  /// Messages adapt to progress state and urgency
  static String _getCriticalUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final shortTitle = _getShortTitle(goalTitle);
    final progressState = _getProgressState(progress);
    final messages = <String>[];

    if (emotion == MascotEmotion.sad) {
      _addProgressMessages(messages, progressState,
        null,
        null,
        CTAMessages.criticalUrgencySadNearComplete);
      
      messages.addAll(CTAMessages.criticalUrgencySadGeneral);
    } else if (emotion == MascotEmotion.worried) {
      _addProgressMessages(messages, progressState,
        null,
        null,
        CTAMessages.criticalUrgencyWorriedNearComplete);
      
      messages.addAll(CTAMessages.criticalUrgencyWorriedGeneral);
    } else {
      _addProgressMessages(messages, progressState,
        null,
        null,
        CTAMessages.criticalUrgencyDefaultNearComplete);
      
      messages.addAll(CTAMessages.criticalUrgencyDefaultGeneral);
    }

    _addContextualMessages(messages, shortTitle, progressLabel, null, UrgencyLevel.critical, progressState);
    return _selectRotatingMessage(messages, now);
  }

  /// Helper to get short title for contextual messages
  static String? _getShortTitle(String? goalTitle) {
    if (goalTitle == null) return null;
    return goalTitle.length > 15 ? '${goalTitle.substring(0, 15)}...' : goalTitle;
  }

  /// Get time context for personalized messaging
  static TimeContext _getTimeContext(int hour) {
    if (hour >= 5 && hour < 12) {
      return TimeContext.morning;
    } else if (hour >= 12 && hour < 17) {
      return TimeContext.afternoon;
    } else if (hour >= 17 && hour < 22) {
      return TimeContext.evening;
    } else {
      return TimeContext.night;
    }
  }

  /// Add progress-specific messages based on progress state
  static void _addProgressMessages(
    List<String> messages,
    ProgressState progressState,
    List<String>? early,
    List<String>? mid,
    List<String>? nearComplete,
  ) {
    switch (progressState) {
      case ProgressState.early:
        if (early != null) messages.addAll(early);
        break;
      case ProgressState.mid:
        if (mid != null) messages.addAll(mid);
        break;
      case ProgressState.nearComplete:
        if (nearComplete != null) messages.addAll(nearComplete);
        break;
    }
  }

  /// Add time-of-day specific messages
  static void _addTimeContextMessages(
    List<String> messages,
    TimeContext timeContext,
    List<String>? morning,
    List<String>? afternoon,
    List<String>? evening,
    List<String>? night,
  ) {
    switch (timeContext) {
      case TimeContext.morning:
        if (morning != null) messages.addAll(morning);
        break;
      case TimeContext.afternoon:
        if (afternoon != null) messages.addAll(afternoon);
        break;
      case TimeContext.evening:
        if (evening != null) messages.addAll(evening);
        break;
      case TimeContext.night:
        if (night != null) messages.addAll(night);
        break;
    }
  }

  /// Add contextual messages with goal title and progress label
  /// Generates goal-specific messages that naturally reference the goal
  static void _addContextualMessages(
    List<String> messages,
    String? shortTitle,
    String? progressLabel,
    [TimeContext? timeContext, UrgencyLevel? urgencyLevel, ProgressState? progressState]
  ) {
    if (shortTitle != null) {
      // Generate goal-specific messages that naturally incorporate the title
      final goalMessages = _generateGoalSpecificMessages(
        shortTitle,
        timeContext,
        urgencyLevel,
        progressState,
      );
      messages.addAll(goalMessages);
    }

    if (progressLabel != null) {
      messages.add("You're at $progressLabel, keep going!");
      messages.add("You're at $progressLabel, all good, fr!");
      messages.add("You're at $progressLabel, let's pick it up, fr!");
      messages.add("You're at $progressLabel, let's keep going, fr!");
      messages.add("You're at $progressLabel, almost there, fr!");
      messages.add("You're at $progressLabel, one more push, fr!");
      messages.add("You're at $progressLabel, let's catch up, fr!");
      messages.add("You're at $progressLabel, this is urgent, fr!");
      messages.add("You're at $progressLabel, still time to turn it around, fr!");
      messages.add("You're at $progressLabel, time to lock in now, fr!");
      messages.add("You're at $progressLabel, let's keep it up, fr!");
    }
  }

  /// Generate goal-specific messages that naturally reference the goal title
  static List<String> _generateGoalSpecificMessages(
    String shortTitle,
    TimeContext? timeContext,
    UrgencyLevel? urgencyLevel,
    ProgressState? progressState,
  ) {
    final messages = <String>[];
    
    // Time-of-day specific goal messages
    if (timeContext == TimeContext.morning) {
      messages.addAll([
        "Let's get $shortTitle done this morning!",
        "Time to work on $shortTitle!",
        "Start your day with $shortTitle!",
        "Let's tackle $shortTitle today!",
        "Morning grind for $shortTitle!",
        "As if you'll start $shortTitle later...",
        "Sure, procrastinate on $shortTitle in the morning...",
        "Not you being a morning person with $shortTitle...",
        "I'm sure you'll get to $shortTitle... eventually...",
        "As if mornings aren't for $shortTitle...",
      ]);
    } else if (timeContext == TimeContext.afternoon) {
      messages.addAll([
        "Keep working on $shortTitle!",
        "Let's make progress on $shortTitle!",
        "Afternoon push for $shortTitle!",
        "Time to focus on $shortTitle!",
        "Let's get $shortTitle done!",
        "As if you'll slow down on $shortTitle...",
        "Sure, take an afternoon break from $shortTitle...",
        "Not you losing momentum on $shortTitle...",
        "I'm sure you'll pick up $shortTitle... eventually...",
        "As if afternoons aren't productive for $shortTitle...",
      ]);
    } else if (timeContext == TimeContext.evening) {
      messages.addAll([
        "Let's finish $shortTitle strong!",
        "Last push for $shortTitle!",
        "Wrap up $shortTitle today!",
        "Finish $shortTitle before the day ends!",
        "Let's complete $shortTitle!",
        "As if you'll finish $shortTitle tmrw...",
        "Sure, leave $shortTitle for tmrw...",
        "Not you ending the day without $shortTitle...",
        "I'm sure you'll finish $shortTitle... eventually...",
        "As if evenings aren't for finishing $shortTitle...",
      ]);
    } else if (timeContext == TimeContext.night) {
      messages.addAll([
        "Let's finish $shortTitle before bed!",
        "One more push for $shortTitle!",
        "Late night grind for $shortTitle!",
        "Let's wrap up $shortTitle!",
        "Finish $shortTitle tonight!",
        "As if you'll remember $shortTitle tmrw...",
        "Sure, do $shortTitle in the morning...",
        "Not you being a night owl with $shortTitle...",
        "I'm sure you'll remember $shortTitle... eventually...",
        "As if sleep is more important than $shortTitle...",
      ]);
    }

    // Progress-specific goal messages
    if (progressState == ProgressState.early) {
      messages.addAll([
        "Let's start $shortTitle!",
        "Time to begin $shortTitle!",
        "Let's get $shortTitle going!",
        "Start working on $shortTitle!",
        "Let's kick off $shortTitle!",
        "As if you'll start $shortTitle later...",
        "Sure, delay starting $shortTitle...",
        "Not you procrastinating on $shortTitle...",
        "I'm sure you'll begin $shortTitle... eventually...",
        "As if starting $shortTitle isn't important...",
      ]);
    } else if (progressState == ProgressState.nearComplete) {
      messages.addAll([
        "Almost done with $shortTitle!",
        "Finish $shortTitle, you're so close!",
        "One more push for $shortTitle!",
        "Let's complete $shortTitle!",
        "You're almost there with $shortTitle!",
        "As if you won't finish $shortTitle...",
        "Sure, stop when you're almost done with $shortTitle...",
        "Not you being so close to finishing $shortTitle...",
        "I'm sure you'll complete $shortTitle... eventually...",
        "As if finishing $shortTitle isn't worth it...",
      ]);
    }

    // Urgency-specific goal messages
    if (urgencyLevel == UrgencyLevel.low) {
      messages.addAll([
        "You're ahead on $shortTitle, keep going!",
        "You're crushing $shortTitle!",
        "Keep it up with $shortTitle!",
        "You're doing great with $shortTitle!",
        "Stay on track with $shortTitle!",
        "As if you're not crushing $shortTitle...",
        "Sure, slow down on $shortTitle...",
        "Not you being too good at $shortTitle...",
        "I'm sure you'll stop crushing $shortTitle...",
        "As if consistency with $shortTitle isn't key...",
      ]);
    } else if (urgencyLevel == UrgencyLevel.medium) {
      messages.addAll([
        "Let's work on $shortTitle!",
        "Time to focus on $shortTitle!",
        "Let's make progress on $shortTitle!",
        "Keep pushing on $shortTitle!",
        "Stay on $shortTitle!",
        "As if you don't need to work on $shortTitle...",
        "Sure, you'll get to $shortTitle later...",
        "Not you forgetting about $shortTitle...",
        "I'm sure you'll focus on $shortTitle... eventually...",
        "As if $shortTitle isn't important...",
      ]);
    } else if (urgencyLevel == UrgencyLevel.high) {
      messages.addAll([
        "We're behind on $shortTitle, let's catch up!",
        "Time to hustle on $shortTitle!",
        "We need to catch up on $shortTitle!",
        "Let's turn it around with $shortTitle!",
        "Rally mode for $shortTitle!",
        "As if you're not behind on $shortTitle...",
        "Sure, take your time with $shortTitle...",
        "Not you being late on $shortTitle...",
        "I'm sure you'll catch up on $shortTitle... eventually...",
        "As if deadlines for $shortTitle aren't real...",
      ]);
    } else if (urgencyLevel == UrgencyLevel.critical) {
      messages.addAll([
        "This is urgent for $shortTitle, do it now!",
        "We can still fix $shortTitle, you got this!",
        "Time to lock in on $shortTitle, this is it!",
        "No more delays on $shortTitle!",
        "Emergency mode for $shortTitle!",
        "As if $shortTitle isn't urgent...",
        "Sure, delay $shortTitle more...",
        "Not you procrastinating on $shortTitle...",
        "I'm sure you'll fix $shortTitle... eventually...",
        "As if urgency for $shortTitle isn't real...",
      ]);
    }

    // General goal-specific messages
    messages.addAll([
      "Let's work on $shortTitle!",
      "Time to focus on $shortTitle!",
      "Keep going with $shortTitle!",
      "Let's make progress on $shortTitle!",
      "Stay on $shortTitle!",
      "Don't forget about $shortTitle!",
      "Let's get $shortTitle done!",
      "You got this with $shortTitle!",
      "As if you'll forget about $shortTitle...",
      "Sure, you'll get to $shortTitle later...",
      "Not you being too busy for $shortTitle...",
      "I'm sure you'll work on $shortTitle... eventually...",
      "As if $shortTitle isn't important...",
      "Sure, skip $shortTitle today...",
      "Not you procrastinating on $shortTitle...",
    ]);

    return messages;
  }

  /// Select a rotating message from a list (frequent rotation based on time)
  /// Rotates every 5 minutes for more frequent variety
  static String _selectRotatingMessage(List<String> options, DateTime now) {
    if (options.isEmpty) return "Let's go";
    // Use 5-minute intervals for frequent rotation
    // Combines hour, minute, and 5-minute block for variety
    final fiveMinuteBlock = now.minute ~/ 5;
    final rotationSeed = (now.hour * 12) + fiveMinuteBlock; // 12 blocks per hour
    final index = rotationSeed % options.length;
    return options[index];
  }

  /// Get progress state based on completion percentage
  static ProgressState _getProgressState(double progress) {
    if (progress < 0.25) {
      return ProgressState.early;
    } else if (progress < 0.75) {
      return ProgressState.mid;
    } else {
      return ProgressState.nearComplete;
    }
  }
}

/// Time context for personalized messaging
enum TimeContext {
  morning,
  afternoon,
  evening,
  night,
}

/// Progress state for contextual messaging
enum ProgressState {
  early,        // 0-25% complete
  mid,          // 25-75% complete
  nearComplete, // 75-100% complete
}
