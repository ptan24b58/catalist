/// Application-wide constants
class AppConstants {
  // Goal configuration
  static const int minTarget = 1;
  static const int maxTarget = 100;
  static const int defaultTarget = 1;
  static const int defaultMaxTarget = 20; // For UI slider
  static const int maxMilestones = 20;

  // Title validation
  static const int minTitleLength = 1;
  static const int maxTitleLength = 100;

  // Mascot configuration
  static const Duration celebrateDuration = Duration(seconds: 5);

  // Widget snapshot
  static const int snapshotVersion = 2; // Bumped for goal redesign

  // Urgency thresholds
  static const double urgencyHappy = 0.2;
  static const double urgencyNeutral = 0.5;
  static const double urgencyWorried = 0.8;

  // Urgency weights for daily goals
  static const double progressWeight = 0.5;
  static const double timeWeight = 0.4;
  static const double streakWeight = 0.1;

  // Urgency weights for long-term goals
  static const double deadlineWeight = 0.6;
  static const double longTermProgressWeight = 0.4;

  // Error messages
  static const String errorGoalNotFound = 'Goal not found';
  static const String errorInvalidInput = 'Invalid input provided';
  static const String errorSaveFailed = 'Failed to save goal';
  static const String errorLoadFailed = 'Failed to load goals';
}
