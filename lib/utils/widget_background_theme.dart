import 'constants.dart';

/// Widget background status levels
enum WidgetBackgroundStatus {
  empty,
  onTrack,
  behind,
  urgent,
  celebrate,
  endOfDay,
}

/// Time bands for background theming
enum TimeBand {
  dawn,   // 5am - 11am
  day,    // 11am - 5pm
  dusk,   // 5pm - 10pm
  night,  // 10pm - 5am
}

/// Utility class for widget background theming
class WidgetBackgroundTheme {
  WidgetBackgroundTheme._(); // Static-only class

  /// Get the time band for a given time
  static TimeBand getTimeBand(DateTime time) {
    final hour = time.hour;
    
    if (hour >= AppConstants.endOfDayEndHour && hour < AppConstants.timeBandDawnEnd) {
      return TimeBand.dawn;
    } else if (hour >= AppConstants.timeBandDawnEnd && hour < AppConstants.timeBandDayEnd) {
      return TimeBand.day;
    } else if (hour >= AppConstants.timeBandDayEnd && hour < AppConstants.timeBandDuskEnd) {
      return TimeBand.dusk;
    } else {
      return TimeBand.night;
    }
  }

  /// Get the status name as a string
  static String statusName(WidgetBackgroundStatus status) {
    return status.name;
  }

  /// Get the time band name as a string
  static String timeBandName(TimeBand band) {
    return band.name;
  }

  /// Get a variant index for visual variation (0-2)
  /// Based on time to create deterministic but varied backgrounds
  static int getVariant(DateTime time, String statusName) {
    // Use minute and status to create variation
    final seed = time.minute + statusName.hashCode;
    return seed.abs() % 3;
  }

  /// Get background color hex for status (for native widget use)
  static String getBackgroundColorHex(WidgetBackgroundStatus status, TimeBand band) {
    // Base colors by status
    switch (status) {
      case WidgetBackgroundStatus.empty:
        return _getEmptyColor(band);
      case WidgetBackgroundStatus.onTrack:
        return _getOnTrackColor(band);
      case WidgetBackgroundStatus.behind:
        return _getBehindColor(band);
      case WidgetBackgroundStatus.urgent:
        return _getUrgentColor(band);
      case WidgetBackgroundStatus.celebrate:
        return _getCelebrateColor(band);
      case WidgetBackgroundStatus.endOfDay:
        return _getEndOfDayColor(band);
    }
  }

  static String _getEmptyColor(TimeBand band) {
    switch (band) {
      case TimeBand.dawn:
        return '#E8F0FE'; // Light blue
      case TimeBand.day:
        return '#F0F4F8'; // Light gray-blue
      case TimeBand.dusk:
        return '#E8E0F0'; // Light purple
      case TimeBand.night:
        return '#1A1A2E'; // Dark blue
    }
  }

  static String _getOnTrackColor(TimeBand band) {
    switch (band) {
      case TimeBand.dawn:
        return '#E3F2E1'; // Soft green
      case TimeBand.day:
        return '#D4EDDA'; // Light green
      case TimeBand.dusk:
        return '#C8E6C9'; // Sage green
      case TimeBand.night:
        return '#1B3D2F'; // Dark green
    }
  }

  static String _getBehindColor(TimeBand band) {
    switch (band) {
      case TimeBand.dawn:
        return '#FFF8E1'; // Light yellow
      case TimeBand.day:
        return '#FFF3CD'; // Warm yellow
      case TimeBand.dusk:
        return '#FFE0B2'; // Soft orange
      case TimeBand.night:
        return '#3D3D1B'; // Dark yellow-green
    }
  }

  static String _getUrgentColor(TimeBand band) {
    switch (band) {
      case TimeBand.dawn:
        return '#FFEBEE'; // Light red
      case TimeBand.day:
        return '#FFCDD2'; // Soft red
      case TimeBand.dusk:
        return '#FFAB91'; // Coral
      case TimeBand.night:
        return '#3D1B1B'; // Dark red
    }
  }

  static String _getCelebrateColor(TimeBand band) {
    switch (band) {
      case TimeBand.dawn:
        return '#F3E5F5'; // Light purple
      case TimeBand.day:
        return '#E1BEE7'; // Lavender
      case TimeBand.dusk:
        return '#CE93D8'; // Purple
      case TimeBand.night:
        return '#2D1B3D'; // Dark purple
    }
  }

  static String _getEndOfDayColor(TimeBand band) {
    // Always night-themed for end of day
    return '#1A1A2E'; // Dark blue
  }
}
