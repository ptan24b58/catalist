/// CTA messages for the flow: empty, daily focus, long-term focus, end of day.
/// Kept minimal to match CTA_engine.txt and keep the app light.
class CTAMessages {
  CTAMessages._();

  // ---------- Empty (by time) ----------
  static const List<String> emptyMorning = [
    "Add a goal rq!", "Create a goal fr!", "Set a goal, let's go!",
    "Add your first goal!", "Add goal today!", "Let's add a goal!",
  ];
  static const List<String> emptyAfternoon = [
    "Add a goal!", "Create a goal fr!", "Add goal rq!",
    "New goal time!", "Add goal today!", "Set up a goal!",
  ];
  static const List<String> emptyEvening = [
    "Add a goal before bed!", "Add goal rq!", "Set a goal, let's go!",
    "Add goal today!", "Let's add a goal!", "Create goal, we got this!",
  ];
  static const List<String> emptyNight = [
    "Add goal for tmrw!", "Create goal for tmrw!", "Set goal for tmrw!",
    "Add tmrw's goal!", "Add goal, future you will thank you!",
  ];

  // ---------- End of day (11pm+) ----------
  static const List<String> endOfDay = [
    "Go to bed soon!", "Rest up for tmrw!", "Get some sleep!",
    "Wind down, you've got this!", "Call it a night soon!",
    "Rest well for tomorrow!", "Sleep soon, no cap!",
  ];

  // ---------- Daily: completed one (5 min) / all done (rest of day) ----------
  static const List<String> completedDaily = [
    "You did it! That's a W fr!", "You ate that, period!", "You slayed, no cap!",
    "Big W, you're him fr!", "Period, you got it!", "That's fire, keep going!",
  ];
  static const List<String> allDailyComplete = [
    "All done for today! You're him fr!", "Daily goals cleared, that's a W!",
    "You finished everything today, no cap!", "Today's list cleared!",
    "Every daily goal done! Period!", "You're done for today! That's a dub!",
  ];

  // ---------- Long-term: completed (5 min) ----------
  static const List<String> completedLongTerm = [
    "You did that! That's huge fr!", "Major W, you're different!",
    "That's crazy, you're built different!", "That's a major dub, no cap!",
    "You're him fr, that's huge!", "That's a big W!",
  ];

  // ---------- Daily in progress (urgency) ----------
  static const List<String> dailyUrgency = [
    "Log your progress rq!", "Update your progress!", "Continue your goal!",
    "Log your progress now!", "Keep going, you got this!",
    "Complete your goal, almost there!", "Finish your goal, let's go!",
  ];

  // ---------- Long-term in progress (urgency, shown during focus hour) ----------
  static const List<String> longTermUrgency = [
    "Work on your long-term goal!", "Update your progress!",
    "Keep pushing on it!", "Log progress, you got this!",
    "Don't forget about it!", "Check in on your goal!",
  ];
}
