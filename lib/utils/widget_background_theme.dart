import '../domain/mascot_state.dart';
import 'constants.dart';
import 'time_of_day.dart';

/// Goal-status bucket for widget background theming.
/// Drives gradient/pattern choice alongside [TimeOfDayBand].
enum WidgetBackgroundStatus {
  celebrate, // Done / win — warm gold, confetti vibe
  onTrack,   // Low urgency — calm blue/teal
  behind,    // Medium/high urgency — warm coral/peach, “attention”
  urgent,    // Critical/overdue — soft red/warm pink
  empty,     // No goal — inviting lavender/blue
  endOfDay,  // 11pm+ — use empty_night on Android
}

/// Computes widget background theme from goal status and current time.
/// Used by [WidgetSnapshotService] and consumed by the native widget.
class WidgetBackgroundTheme {
  WidgetBackgroundTheme._();

  static const _statusNames = {
    WidgetBackgroundStatus.celebrate: 'celebrate',
    WidgetBackgroundStatus.onTrack: 'on_track',
    WidgetBackgroundStatus.behind: 'behind',
    WidgetBackgroundStatus.urgent: 'urgent',
    WidgetBackgroundStatus.empty: 'empty',
    WidgetBackgroundStatus.endOfDay: 'end_of_day',
  };

  /// Status from top-goal urgency + mascot emotion (and optional completion).
  static WidgetBackgroundStatus getStatus({
    required String emotion,
    required double urgency,
    bool hasGoal = true,
    bool isCompleted = false,
  }) {
    if (!hasGoal) return WidgetBackgroundStatus.empty;
    if (isCompleted || emotion == MascotEmotion.celebrate.name) {
      return WidgetBackgroundStatus.celebrate;
    }
    if (urgency >= AppConstants.urgencyWorried) return WidgetBackgroundStatus.urgent;
    if (urgency >= AppConstants.urgencyHappy) return WidgetBackgroundStatus.behind;
    return WidgetBackgroundStatus.onTrack;
  }

  /// Time band from hour-of-day (local time). Uses shared [timeBandFromHour].
  static TimeOfDayBand getTimeBand(DateTime now) => timeBandFromHour(now.hour);

  /// Snapshot-friendly string for status (matches Android drawable names).
  static String statusName(WidgetBackgroundStatus s) => _statusNames[s]!;

  /// Snapshot-friendly string for time band (matches Android drawable names).
  static String timeBandName(TimeOfDayBand t) => t.drawableName;

  /// Variant 1–3 for multiple backgrounds per (status, time). Deterministic by day + hour + status.
  static int getVariant(DateTime now, String statusName) {
    final day = now.year * 1000 + now.day;
    final seed = day + now.hour * 10 + statusName.hashCode.abs();
    return (seed % 3) + 1;
  }
}
