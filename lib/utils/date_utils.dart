/// Utility functions for date operations
class DateUtils {
  /// Normalize a DateTime to midnight (start of day)
  static DateTime normalizeToDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Check if two dates are on the same day
  static bool isSameDay(DateTime date1, DateTime date2) =>
      normalizeToDay(date1) == normalizeToDay(date2);

  /// Get yesterday's date (normalized to midnight)
  static DateTime getYesterday(DateTime now) =>
      normalizeToDay(now).subtract(const Duration(days: 1));

  /// Get end of day for a given date
  static DateTime getEndOfDay(DateTime date) =>
      normalizeToDay(date).add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

  /// Format date for display (Today, Yesterday, or MM/DD/YYYY)
  static String formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final dateDay = normalizeToDay(date);
    final today = normalizeToDay(now);

    if (dateDay == today) return 'Today';
    if (dateDay == getYesterday(now)) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
  }
}
