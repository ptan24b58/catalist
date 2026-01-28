import 'cta_messages.dart';

/// Flow-based CTA engine. Matches CTA_engine.txt:
/// - empty → empty CTA
/// - daily focus: completed-one (5min) | all-daily-done | in-progress
/// - long-term focus: completed (5min) | in-progress (during focus hour)
/// - end of day (11pm+) → go to bed CTA
enum CTAContext {
  empty,
  endOfDay,
  dailyCompletedOne5Min,
  dailyAllComplete,
  dailyInProgress,
  longTermCompleted5Min,
  longTermInProgress,
}

class CTAEngine {
  /// Returns CTA for the given flow context. Rotates by 5‑min block.
  /// [progressLabel] is used for daily-in-progress when provided (e.g. "2/5").
  static String generateFromContext(CTAContext context, DateTime now, [String? progressLabel]) {
    final list = _messagesFor(context, now);
    if (list.isEmpty) return "Let's go";
    final seed = (now.hour * 12) + (now.minute ~/ 5);
    final i = seed % list.length;
    String msg = list[i];
    if (context == CTAContext.dailyInProgress && progressLabel != null && list.length > 0) {
      // Sometimes show progress-specific line
      if (i % 3 == 0) return "You're at $progressLabel, keep going!";
    }
    return msg;
  }

  static List<String> _messagesFor(CTAContext context, DateTime now) {
    switch (context) {
      case CTAContext.empty:
        return _emptyByHour(now.hour);
      case CTAContext.endOfDay:
        return CTAMessages.endOfDay;
      case CTAContext.dailyCompletedOne5Min:
        return CTAMessages.completedDaily;
      case CTAContext.dailyAllComplete:
        return CTAMessages.allDailyComplete;
      case CTAContext.dailyInProgress:
        return CTAMessages.dailyUrgency;
      case CTAContext.longTermCompleted5Min:
        return CTAMessages.completedLongTerm;
      case CTAContext.longTermInProgress:
        return CTAMessages.longTermUrgency;
    }
  }

  static List<String> _emptyByHour(int hour) {
    if (hour >= 5 && hour < 11) return CTAMessages.emptyMorning;
    if (hour >= 11 && hour < 17) return CTAMessages.emptyAfternoon;
    if (hour >= 17 && hour < 22) return CTAMessages.emptyEvening;
    return CTAMessages.emptyNight;
  }
}
