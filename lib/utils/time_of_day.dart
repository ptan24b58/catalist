import 'constants.dart';

/// Single source of truth for time-of-day bands. Used by CTA messaging and
/// widget background theming so both stay in sync.
///
/// Bands (by hour, exclusive end): dawn 5–11, day 11–17, dusk 17–22, night 22–5.
enum TimeOfDayBand {
  dawn,
  day,
  dusk,
  night,
}

/// Returns the time band for the given hour (0–23).
TimeOfDayBand timeBandFromHour(int hour) {
  if (hour >= 5 && hour < AppConstants.timeBandDawnEnd) return TimeOfDayBand.dawn;
  if (hour >= AppConstants.timeBandDawnEnd && hour < AppConstants.timeBandDayEnd) {
    return TimeOfDayBand.day;
  }
  if (hour >= AppConstants.timeBandDayEnd && hour < AppConstants.timeBandDuskEnd) {
    return TimeOfDayBand.dusk;
  }
  return TimeOfDayBand.night;
}

/// Snapshot/drawable name for this band (matches Android drawable names).
extension TimeOfDayBandExtension on TimeOfDayBand {
  String get drawableName => switch (this) {
        TimeOfDayBand.dawn => 'dawn',
        TimeOfDayBand.day => 'day',
        TimeOfDayBand.dusk => 'dusk',
        TimeOfDayBand.night => 'night',
      };
}
