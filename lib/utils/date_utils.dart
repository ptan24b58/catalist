/// Utility functions for date operations
class DateUtils {
  /// Normalize a DateTime to midnight (start of day)
  static DateTime normalizeToDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if two dates are on the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return normalizeToDay(date1) == normalizeToDay(date2);
  }

  /// Get yesterday's date (normalized to midnight)
  static DateTime getYesterday(DateTime now) {
    final today = normalizeToDay(now);
    return today.subtract(const Duration(days: 1));
  }

  /// Get end of day for a given date
  static DateTime getEndOfDay(DateTime date) {
    final day = normalizeToDay(date);
    return day
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));
  }

  /// Format date for display (Today, Yesterday, or MM/DD/YYYY)
  static String formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final today = normalizeToDay(now);
    final dateDay = normalizeToDay(date);
    final yesterday = getYesterday(now);

    if (dateDay == today) {
      return 'Today';
    } else if (dateDay == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
