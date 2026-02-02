/// Application-wide constants
class AppConstants {
  AppConstants._(); // Private constructor

  // ============ Goal Configuration ============
  static const int minTarget = 1;
  static const int maxTarget = 100;
  static const int defaultTarget = 1;
  static const int defaultMaxTarget = 20; // For UI slider
  static const int maxMilestones = 20;
  static const int maxIdLength = 100;

  // ============ Title Validation ============
  static const int minTitleLength = 1;
  static const int maxTitleLength = 100;

  // ============ Mascot Configuration ============
  static const Duration celebrateDuration = Duration(minutes: 5);

  // ============ Widget Snapshot ============
  static const int snapshotVersion = 2; // Bumped for goal redesign

  // ============ Time-of-day band boundaries (hour, exclusive end) ============
  /// Bands: dawn 5–11, day 11–17, dusk 17–22, night 22–5. Used by CTA and widget backgrounds.
  static const int timeBandDawnEnd = 11;
  static const int timeBandDayEnd = 17;
  static const int timeBandDuskEnd = 22;

  /// Hour at which "end of day" / go to bed CTA starts (23 = 11pm).
  static const int endOfDayStartHour = 23;
  
  /// Hour at which "end of day" / go to bed CTA ends (5 = 5am).
  static const int endOfDayEndHour = 5;

  /// Hours when widget focuses on long-term goals (1 hr each). Rest of time = daily focus.
  static const List<int> longTermFocusHours = [14, 20];

  // ============ Urgency Thresholds ============
  static const double urgencyHappy = 0.2;
  static const double urgencyNeutral = 0.5;
  static const double urgencyWorried = 0.8;

  // ============ Urgency Weights (Daily Goals) ============
  static const double progressWeight = 0.5;
  static const double timeWeight = 0.4;
  static const double streakWeight = 0.1;

  // ============ Urgency Weights (Long-term Goals) ============
  static const double deadlineWeight = 0.6;
  static const double longTermProgressWeight = 0.4;

  // ============ Event Configuration ============
  static const int maxEventTitleLength = 100;
  static const int maxEventNotesLength = 500;

  // ============ Error Messages ============
  static const String errorGoalNotFound = 'Goal not found';
  static const String errorInvalidInput = 'Invalid input provided';
  static const String errorSaveFailed = 'Failed to save goal';
  static const String errorLoadFailed = 'Failed to load goals';
  static const String errorLoadGoalDetails = 'Failed to load goal details';
  static const String errorLogProgress = 'Failed to log progress';
  static const String errorUpdateProgress = 'Failed to update progress';
  static const String errorDeleteGoal = 'Failed to delete goal';

  // ============ Success Messages ============
  static const String successProgressLogged = 'Progress logged!';
  static const String successProgressUpdated = 'Progress updated!';
  static const String successGoalCompleted = 'Goal completed!';

  // ============ Validation Messages ============
  static const String validationAddMilestone = 'Please add at least one milestone';
  static const String validationValidTarget = 'Please enter a valid target value';
  static const String validationValidNumber = 'Please enter a valid number';

  // ============ Emotion Messages ============
  static const Map<String, String> emotionMessages = {
    'happy': "You're doing great!",
    'neutral': "Let's keep going!",
    'worried': "Don't forget me...",
    'sad': "I miss you!",
    'celebrate': "Amazing work!",
  };

  /// Get emotion message by emotion type
  static String getEmotionMessage(String emotion) {
    return emotionMessages[emotion.toLowerCase()] ?? "Let's keep going!";
  }
}
