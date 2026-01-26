import '../domain/mascot_state.dart';
import '../models/widget_snapshot.dart';
import 'urgency_engine.dart';

/// Generates dynamic, personalized CTAs with Gen Z-focused messaging
/// 
/// Creates context-aware, engaging call-to-action messages that adapt to:
/// - Urgency level and progress state
/// - Time of day and context
/// - Goal type and completion status
/// - Mascot emotion and personality
class CTAEngine {
  /// Generate a personalized CTA for the widget
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

    // Generate CTA based on urgency level and mascot emotion
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
  static String _getEmptyStateCTA(DateTime now) {
    final hour = now.hour;
    final messages = [
      if (hour >= 6 && hour < 12) ...[
        "Yo what we doing today?",
        "Add something rq, let's get it",
        "What's the plan? Ngl we should add one",
        "I'm here, what's your move?",
        "Add a goal, we'll get it done",
        "What you got planned? Lowkey add one",
        "Let's set something up fr",
        "What we working on? Add one",
        "Add one and we'll get started",
        "What's on your mind? Let's add something",
        "Let's add something fr, no cap",
        "What you trying to do? Add it",
        "Add a goal, I got you fr",
        "What's the move? Let's add one",
        "Set something rq, we got this",
        "Add one, let's go",
        "What we doing? Add something",
        "Lowkey should add a goal",
      ] else if (hour >= 12 && hour < 18) ...[
        "What's the move? Add something",
        "Add something and let's go",
        "What we doing? Add one rq",
        "Let's add one, we got time",
        "What you got? Add it",
        "Add a goal, we chilling",
        "What's on your list? Add one",
        "Let's set something up fr",
        "Add one and let's do it, no cap",
        "What you working on? Add it",
        "Let's add something",
        "What's the plan? Add one",
        "Add one, I'm here fr",
        "What we doing? Lowkey add one",
        "Let's get something going, add it",
        "Add one, we got this",
        "Highkey should add a goal",
        "Add something rq, let's go",
      ] else if (hour >= 18 && hour < 22) ...[
        "One more before bed? Add it",
        "What we doing tonight? Add one",
        "Add one rq, let's finish strong",
        "One more thing?",
        "What's the move? Add one",
        "Add one and let's wrap it, fr",
        "One more before sleep? Let's go",
        "What you got left? Add it",
        "Let's add one more",
        "One more push? Add it",
        "What's on your mind? Add one",
        "Add one rq, no cap",
        "Let's do one more",
        "What we finishing? Add it",
        "Add one more",
        "Lowkey one more before bed",
        "Add one, we got this fr",
      ] else ...[
        "Late night? Add one for tmrw",
        "Set something for tmrw, future you will thank you",
        "Add one for when you wake up",
        "Set it now, thank yourself later fr",
        "What you doing tmrw? Add it",
        "Add one for the morning, we got this",
        "Set something for tmrw, no cap",
        "Future you got this, add one",
        "Add one, I'll remind you fr",
        "What's the plan for tmrw? Add it",
        "Set it for tmrw",
        "Add one, we'll get it done, no cap",
        "Late night planning? Add it",
        "Set something for when you're up, fr",
        "Add one for tmrw",
        "Lowkey set it for tomorrow",
        "Add one, future you will be happy",
      ]
    ];

    return _randomSelect(messages);
  }

  /// Get CTA for completed goals
  static String _getCompletedCTA(DateTime now, String goalType) {
    if (goalType == 'daily') {
      return _randomSelect([
        "You did it! That's a W fr",
        "You ate that, period",
        "You slayed, no cap",
        "Big W, you're him fr",
        "That's it, you did that",
        "Period, you got it",
        "You're that girl, fr",
        "That's fire, keep going",
        "You're him, no cap",
        "That's a dub, you're different",
        "You did that, I'm proud fr",
        "That's it right there",
        "Period, you're built different",
        "You're actually him, fr",
        "That's a major W, no cap",
        "You're built different",
        "That's crazy, you did that",
        "You're him for that",
        "That's actually wild, fr",
        "You're different, no cap",
        "That's a big W, you ate",
        "You're actually different",
        "That's it fr, keep it up",
        "You're him, that's a fact",
        "That's a W, you're that person",
      ]);
    } else {
      return _randomSelect([
        "You did that! That's huge fr",
        "Major W, you're different",
        "That's crazy, you're built different",
        "That's actually insane, no cap",
        "That's wild, you did that",
        "You're actually crazy, fr",
        "That's actually wild",
        "You're him fr, that's huge",
        "That's a major dub, no cap",
        "You're different for that",
        "That's actually crazy, fr",
        "You're built different",
        "That's huge fr, I'm proud",
        "You're actually him",
        "That's wild fr, no cap",
        "You're different, that's a fact",
        "That's actually different",
        "You're him for that, fr",
        "That's a big W",
        "You're actually built different",
        "That's crazy fr, no cap",
        "You're different for real, fr",
        "That's actually wild, you did that",
        "You're him, that's insane",
        "That's a major W, you're different",
      ]);
    }
  }

  /// Generate contextual CTA based on urgency and emotion
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
      return _randomSelect([
        "You're on fire, keep it going fr",
        "Don't stop, you're on one",
        "Ride the wave, you got this, no cap",
        "You're in your bag, keep going",
        "This is your moment, don't let up",
        "Keep the energy, you're locked in, fr",
        "You're on fire fr, keep pushing, no cap",
        "Don't slow down, you're on a roll",
        "Keep going strong, I see you, fr",
        "You're in the zone, don't break it",
        "Keep that vibe going, no cap",
        "You're on one fr, keep it up",
        "Don't let it stop, you're doing great",
        "Keep that energy, you're different, fr",
        "You're locked in, keep going, no cap",
        "Don't break the streak, you got this",
        "Keep going hard, I'm here for it, fr",
        "You're on fire, keep the momentum, no cap",
        "Don't let up now, you're winning",
        "Keep the flow, you're doing it",
        "You're in your era, keep going",
        "This is your time, don't stop",
        "You're winning, keep it up",
      ]);
    }

    // Combine urgency level with emotion for nuanced messaging
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
  static String _getLowUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final shortTitle = goalTitle != null && goalTitle.length > 15 
        ? goalTitle.substring(0, 15) + "..." 
        : goalTitle;
    
    if (emotion == MascotEmotion.happy) {
      return _randomSelect([
        "You're ahead, keep it up",
        "You're doing great, stay on it, fr",
        "You got this, you're chilling, no cap",
        "You're ahead fr, keep going",
        "You're doing amazing, I see you",
        "Stay locked in, you're winning",
        "You got this fr, keep pushing, no cap",
        "You're good, keep that energy",
        "You're chilling fr, all good, no cap",
        "You're ahead of it, keep it up",
        "You're doing great, stay on that grind, fr",
        "You're built for this, keep going",
        "You're good to go, keep it moving, no cap",
        "You're chilling and winning, keep it up",
        "All good, you're ahead and winning, fr",
        "Keep that momentum, you're doing it right",
        if (shortTitle != null) "You're ahead on $shortTitle, keep going",
        if (progressLabel != null) "You're at $progressLabel, keep going",
      ]);
    }

    // Neutral but low urgency
    return _randomSelect([
      "You got this, keep going",
      "You're on track, doing good, fr",
      "Keep it up, you're fine, no cap",
      "All good, you're good",
      "You got this fr, keep pushing, no cap",
      "You're on track fr, keep going",
      "Doing good fr, you're locked in, no cap",
      "Keep it up fr, you're on it",
      "You're fine fr, all good, no cap",
      "You're good fr, keep it moving",
      "You're chilling, doing great, fr",
      "Keep it moving, you're doing fine",
      "All good, keep going, you got this, no cap",
      "You're on it, keep pushing",
      "You're good to go, doing great, fr",
      "You're locked in, keep that energy",
      if (shortTitle != null) "You're on track with $shortTitle",
      if (progressLabel != null) "You're at $progressLabel, all good, fr",
    ]);
  }

  /// Medium urgency - normal pace
  static String _getMediumUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final hour = now.hour;
    final timeContext = _getTimeContext(hour);
    final shortTitle = goalTitle != null && goalTitle.length > 15 
        ? goalTitle.substring(0, 15) + "..." 
        : goalTitle;

    if (emotion == MascotEmotion.worried) {
      return _randomSelect([
        "Let's get back on it, you got this",
        "Time to focus, pick it up, fr",
        "You got this, let's go, no cap",
        "Pick it up, we got this",
        "Let's go, time to move, fr",
        "Time to focus, let's get back on track",
        "You got this fr, let's lock in, no cap",
        "Pick it up fr, we can do this",
        "Let's go fr, time to get serious, no cap",
        "Time to focus fr, you got this",
        "Let's get it together, we got this, fr",
        "Time to get serious, let's turn it around",
        "You got this no cap, pick it up, fr",
        "Pick it up now, we're in this together",
        "Let's turn it around, you got this, no cap",
        "Time to get on it, let's go",
        "Let's get back on it",
        "Lowkey time to focus up",
        if (shortTitle != null) "Let's get back on $shortTitle",
        if (progressLabel != null) "You're at $progressLabel, let's pick it up, fr",
      ]);
    }

    // Default medium urgency messages
    return _randomSelect([
      if (timeContext == TimeContext.morning) ...[
        "Morning grind, let's get it",
        "Let's get it, start strong, fr",
        "Start strong, time to move",
        "Time to move, morning vibes, no cap",
        "Let's get it started, you got this",
        "Start the day right, let's go, fr",
        "Time to get on it, morning energy",
        "Let's get it fr, start strong, no cap",
        "Start strong fr, we got this",
        "Time to move fr, let's get this day",
        "Morning grind fr, start it off right, no cap",
        "Let's get this day, time to get going",
        "Start it off right, morning move, fr",
        "Time to get going, let's get it going",
        "Morning move, start it up, no cap",
        "Let's get it this morning",
        "Lowkey morning grind time",
        if (shortTitle != null) "Let's get $shortTitle done this morning",
        if (progressLabel != null) "You're at $progressLabel, let's keep going, fr",
      ] else if (timeContext == TimeContext.afternoon) ...[
        "Afternoon vibes, keep going",
        "Keep going, you're good, fr",
        "You're good, let's do it",
        "Let's do it, afternoon energy, no cap",
        "Afternoon energy, keep pushing",
        "Keep pushing, you're doing good, fr",
        "You're doing good, let's keep it going",
        "Let's keep it going, afternoon grind, no cap",
        "Afternoon grind, keep going fr",
        "Keep going fr, you're good fr, no cap",
        "You're good fr, let's do it fr",
        "Let's do it fr, afternoon move, no cap",
        "Afternoon move, keep that energy",
        "Keep that energy, you're on it, fr",
        "You're on it, let's keep pushing",
        "Afternoon vibes",
        "Lowkey keep pushing",
        if (shortTitle != null) "Let's keep working on $shortTitle",
        if (progressLabel != null) "You're at $progressLabel, keep pushing, fr",
      ] else if (timeContext == TimeContext.evening) ...[
        "Finish strong, last push",
        "Last push, almost there, fr",
        "Almost there, let's wrap it",
        "Let's wrap it, finish it up, no cap",
        "Finish it up, last push fr",
        "Last push fr, almost there fr, no cap",
        "Almost there fr, let's wrap it up",
        "Let's wrap it up, finish strong fr, no cap",
        "Finish strong fr, last push of the day",
        "Last push of the day, almost done, fr",
        "Almost done, let's finish it",
        "Let's finish it, wrap it up, no cap",
        "Wrap it up, last one",
        "Last one, almost there keep going, fr",
        "Almost there keep going, let's finish strong",
        "Last push, let's go",
        "Lowkey almost there",
        if (shortTitle != null) "Let's finish $shortTitle strong",
        if (progressLabel != null) "You're at $progressLabel, almost there, fr",
      ] else ...[
        "Late night, you got this",
        "You got this, keep going, fr",
        "Keep going, one more thing",
        "One more thing, late night grind, no cap",
        "Late night grind, you got this fr",
        "You got this fr, keep going fr, no cap",
        "Keep going fr, one more thing fr",
        "One more thing fr, late night vibes, no cap",
        "Late night vibes, you got this keep going",
        "You got this keep going, keep pushing, fr",
        "Keep pushing, one more push",
        "One more push, late night energy, no cap",
        "Late night energy, you got this no cap",
        "You got this no cap, keep going strong, fr",
        "Keep going strong, one more before bed",
        "One more before bed",
        "Lowkey late night grind",
        if (shortTitle != null) "Let's finish $shortTitle before bed",
        if (progressLabel != null) "You're at $progressLabel, one more push, fr",
      ],
      "Let's go, you're on it",
      "Time to move, let's do it, fr",
      "You're on it, let's go fr",
      "Let's do it, time to move fr, no cap",
      "You're on it fr, let's get it",
      "Let's get it, time to get on it, fr",
      "You're locked in, let's keep going",
      "Let's keep going, time to push, no cap",
      "You're doing it, let's keep pushing",
      "Let's keep pushing, time to focus, fr",
      "You're on track, let's make moves",
      "Let's go",
      "Lowkey time to move",
      if (shortTitle != null) "Let's work on $shortTitle",
      if (progressLabel != null) "You're at $progressLabel, let's keep it up, fr",
    ]);
  }

  /// High urgency - behind schedule
  static String _getHighUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final shortTitle = goalTitle != null && goalTitle.length > 15 
        ? goalTitle.substring(0, 15) + "..." 
        : goalTitle;
    
    if (emotion == MascotEmotion.worried || emotion == MascotEmotion.sad) {
      return _randomSelect([
        "We need to catch up, you got this",
        "Time to hustle, let's turn it around, fr",
        "Let's turn it around, no cap we got this",
        "No cap we got this, comeback time, fr",
        "Comeback time, rally mode",
        "Rally mode, we're behind but we got this, no cap",
        "We're behind but we got this, time to lock in",
        "Time to lock in, we need to catch up fr, no cap",
        "We need to catch up fr, time to hustle fr",
        "Time to hustle fr, let's turn it around fr, no cap",
        "Let's turn it around fr, we got this",
        "No cap we got this fr, comeback time fr, no cap",
        "Comeback time fr, rally mode activated",
        "Rally mode activated, we're behind but we got this fr, no cap",
        "We're behind but we got this fr, time to lock in fr",
        "Time to lock in fr, we need to move, fr",
        "We need to move, time to get serious",
        "Time to get serious, let's make a comeback, no cap",
        "Let's make a comeback, we got this no cap",
        "We got this no cap, it's comeback time, fr",
        "It's comeback time, rally mode fr",
        "Rally mode fr, we're behind but we can do this, no cap",
        "We're behind but we can do this, time to lock in now",
        "We need to catch up",
        "Lowkey rally mode time",
        if (shortTitle != null) "We need to catch up on $shortTitle",
        if (progressLabel != null) "You're at $progressLabel, let's catch up, fr",
      ]);
    }

    // High urgency but neutral emotion
    return _randomSelect([
      "Pick it up, time to focus",
      "Time to focus, we're behind, fr",
      "We're behind, let's catch up",
      "Let's catch up, crunch time, no cap",
      "Crunch time, time to move",
      "Time to move, let's go, fr",
      "Let's go, pick it up fr",
      "Pick it up fr, time to focus fr, no cap",
      "Time to focus fr, we're behind fr",
      "We're behind fr, let's catch up fr, no cap",
      "Let's catch up fr, crunch time fr",
      "Crunch time fr, time to move fr, no cap",
      "Time to move fr, let's go fr",
      "Let's go fr, pick it up now, fr",
      "Pick it up now, time to focus up",
      "Time to focus up, we're behind let's go, no cap",
      "We're behind let's go, let's catch up quick",
      "Let's catch up quick, it's crunch time, fr",
      "It's crunch time, time to move now",
      "Time to move now, let's go now, no cap",
      "Time to pick it up",
      "Lowkey crunch time",
      if (shortTitle != null) "We're behind on $shortTitle, let's catch up",
      if (progressLabel != null) "You're at $progressLabel, we need to catch up, fr",
    ]);
  }

  /// Critical urgency - overdue or very behind
  static String _getCriticalUrgencyCTA(
    MascotEmotion emotion,
    double progress,
    String goalType,
    DateTime now,
    String? progressLabel,
    String? goalTitle,
  ) {
    final shortTitle = goalTitle != null && goalTitle.length > 15 
        ? goalTitle.substring(0, 15) + "..." 
        : goalTitle;
    
    // Critical + sad/worried = urgent but supportive
    if (emotion == MascotEmotion.sad) {
      return _randomSelect([
        "You got this, it's not too late",
        "Not too late, we can do this, fr",
        "We can do this, there's still time",
        "Still time, don't give up, no cap",
        "Don't give up, comeback time",
        "Comeback time, let's fix this, fr",
        "Let's fix this, we got you",
        "We got you, you got this fr, no cap",
        "You got this fr, not too late fr",
        "Not too late fr, we can do this fr, no cap",
        "We can do this fr, still time fr",
        "Still time fr, don't give up fr, no cap",
        "Don't give up fr, comeback time fr",
        "Comeback time fr, let's fix this fr, no cap",
        "Let's fix this fr, we got you fr",
        "We got you fr, you got this no cap, fr",
        "You got this no cap, it's not too late",
        "It's not too late, we can still do this, no cap",
        "We can still do this, there's still time",
        "There's still time, don't give up now, fr",
        "Don't give up now, it's comeback time",
        "It's comeback time, let's fix this together, no cap",
        "Let's fix this together, we got your back",
        "We got your back, you got this we believe, fr",
        "We got you",
        "Lowkey comeback time",
        if (shortTitle != null) "We can still fix $shortTitle, you got this",
        if (progressLabel != null) "You're at $progressLabel, still time to turn it around, fr",
      ]);
    }

    if (emotion == MascotEmotion.worried) {
      return _randomSelect([
        "Time to lock in, get serious",
        "Get serious, no more delays, fr",
        "No more delays, this is it",
        "This is it, all or nothing, no cap",
        "All or nothing, time to show up",
        "Time to show up, lock in now, fr",
        "Lock in now, do it now",
        "Do it now, time to lock in fr, no cap",
        "Time to lock in fr, get serious fr",
        "Get serious fr, no more delays fr, no cap",
        "No more delays fr, this is it fr",
        "This is it fr, all or nothing fr, no cap",
        "All or nothing fr, time to show up fr",
        "Time to show up fr, lock in now fr, no cap",
        "Lock in now fr, do it now fr",
        "Do it now fr, time to lock in now, fr",
        "Time to lock in now, get serious now",
        "Get serious now, no more delays let's go, no cap",
        "No more delays let's go, this is it no cap",
        "This is it no cap, all or nothing now, fr",
        "All or nothing now, time to show up now",
        "Time to show up now, lock in immediately, no cap",
        "Lock in immediately, do it right now",
        "Time to lock in",
        "Lowkey this is it",
        if (shortTitle != null) "Time to lock in on $shortTitle, this is it",
        if (progressLabel != null) "You're at $progressLabel, time to lock in now, fr",
      ]);
    }

    // Critical urgency default
    return _randomSelect([
      "This is urgent, do it now",
      "Do it now, fix this, fr",
      "Fix this, no time",
      "No time, emergency, no cap",
      "Emergency, now or never",
      "Now or never, time's up, fr",
      "Time's up, this is urgent fr",
      "This is urgent fr, do it now fr, no cap",
      "Do it now fr, fix this fr",
      "Fix this fr, no time fr, no cap",
      "No time fr, emergency fr",
      "Emergency fr, now or never fr, no cap",
      "Now or never fr, time's up fr",
      "Time's up fr, this is urgent no cap, fr",
      "This is urgent no cap, do it right now",
      "Do it right now, fix this immediately, no cap",
      "Fix this immediately, no time to waste",
      "No time to waste, it's an emergency, fr",
      "It's an emergency, now or never for real",
      "Now or never for real, time's actually up, no cap",
      "This is urgent",
      "Lowkey emergency mode",
      if (shortTitle != null) "This is urgent for $shortTitle, do it now",
      if (progressLabel != null) "You're at $progressLabel, this is urgent, fr",
    ]);
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

  /// Randomly select from a list (deterministic based on time)
  static String _randomSelect(List<String> options) {
    if (options.isEmpty) return "Let's go";
    // Use current minute to create variety without randomness
    final index = DateTime.now().minute % options.length;
    return options[index];
  }
}

/// Time context for personalized messaging
enum TimeContext {
  morning,
  afternoon,
  evening,
  night,
}
