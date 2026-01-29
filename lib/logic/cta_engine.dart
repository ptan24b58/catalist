import 'cta_messages.dart';

/// Flow-based CTA engine. Priority order:
/// 1. empty → 2. 5-min celebration → 3. end of day (11pm-5am)
/// 4. long-term focus (14:00, 20:00) → 5. all daily complete → 6. daily in-progress
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
  /// Returns CTA for the given flow context. Rotates by 30‑min block.
  /// [progressLabel] is used for daily-in-progress when provided (e.g. "2/5").
  static String generateFromContext(CTAContext context, DateTime now, [String? progressLabel]) {
    final list = _messagesFor(context, now);
    if (list.isEmpty) return "Vivian, let's go";
    final seed = (now.hour * 2) + (now.minute ~/ 30);
    final i = seed % list.length;
    String msg = list[i];
    if (context == CTAContext.dailyInProgress && progressLabel != null && list.isNotEmpty) {
      if (i % 3 == 0) {
        const p = CTAMessages.progressLabelPrefixes;
        const s = CTAMessages.progressLabelSuffixes;
        final pre = p[seed % p.length];
        final suf = s[seed % s.length];
        return "$pre $progressLabel $suf";
      }
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
