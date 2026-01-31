import '../utils/date_utils.dart';

/// Type of goal - daily (recurring) or long-term (one-time with deadline)
enum GoalType {
  daily,    // Recurring daily goal with streak tracking
  longTerm, // One-time goal with optional deadline
}

/// How progress is measured for the goal
enum ProgressType {
  completion,  // Simple yes/no completion (daily goals)
  percentage,  // 0-100% progress (long-term goals)
  milestones,  // Sub-goals/checkpoints (long-term goals)
  numeric,     // Target value to reach (both goal types)
}

/// A milestone/sub-goal for milestone-based goals
class Milestone {
  final String id;
  final String title;
  final bool completed;
  final DateTime? completedAt;
  final DateTime? deadline;

  const Milestone({
    required this.id,
    required this.title,
    this.completed = false,
    this.completedAt,
    this.deadline,
  });

  Milestone copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? completedAt,
    DateTime? deadline,
  }) {
    return Milestone(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      deadline: deadline ?? this.deadline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'completedAt': completedAt?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
    };
  }

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
    );
  }
}

/// Core domain model for goals
class Goal {
  final String id;
  final String title;
  final GoalType goalType;
  final ProgressType progressType;

  // For numeric goals (e.g., "Save $5000", "Read 12 books")
  final double? targetValue;
  final double currentValue;
  final String? unit; // e.g., "$", "books", "miles", "kg"

  // For percentage goals
  final double percentComplete; // 0-100

  // For milestone goals
  final List<Milestone> milestones;

  // For long-term goals
  final DateTime? deadline;

  // For daily goals (streak system)
  final List<DateTime> todayCompletions;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompletedAt;

  // For long-term goal completion memories
  final String? completionImagePath;  // Path to celebration photo
  final String? completionMemo;       // User's reflection/memo on completion

  // Common
  final DateTime createdAt;

  Goal({
    required this.id,
    required this.title,
    required this.goalType,
    required this.progressType,
    this.targetValue,
    this.currentValue = 0,
    this.unit,
    this.percentComplete = 0,
    this.milestones = const [],
    this.deadline,
    this.todayCompletions = const [],
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedAt,
    this.completionImagePath,
    this.completionMemo,
    required this.createdAt,
  });

  /// Check if this goal is completed
  bool get isCompleted {
    switch (progressType) {
      case ProgressType.completion:
        if (goalType == GoalType.daily) {
          // Daily completion: check if completed today
          return lastCompletedAt != null &&
              DateUtils.isSameDay(lastCompletedAt!, DateTime.now());
        }
        return lastCompletedAt != null;
      case ProgressType.percentage:
        return percentComplete >= 100;
      case ProgressType.milestones:
        return milestones.isNotEmpty &&
            milestones.every((m) => m.completed);
      case ProgressType.numeric:
        if (goalType == GoalType.daily) {
          // Daily numeric: check if today's completions reach the target
          final now = DateTime.now();
          final completionsToday = todayCompletions
              .where((c) => DateUtils.isSameDay(c, now))
              .length;
          return targetValue != null && completionsToday >= targetValue!;
        }
        return targetValue != null && currentValue >= targetValue!;
    }
  }

  /// Get overall progress as a value between 0 and 1
  double getProgress() {
    switch (progressType) {
      case ProgressType.completion:
        if (goalType == GoalType.daily) {
          return isCompleted ? 1.0 : 0.0;
        }
        return isCompleted ? 1.0 : 0.0;
      case ProgressType.percentage:
        return (percentComplete / 100).clamp(0.0, 1.0);
      case ProgressType.milestones:
        if (milestones.isEmpty) return 0.0;
        final completed = milestones.where((m) => m.completed).length;
        return completed / milestones.length;
      case ProgressType.numeric:
        if (targetValue == null || targetValue == 0) return 0.0;
        if (goalType == GoalType.daily) {
          // Daily numeric: progress based on today's completions
          final now = DateTime.now();
          final completionsToday = todayCompletions
              .where((c) => DateUtils.isSameDay(c, now))
              .length;
          return (completionsToday / targetValue!).clamp(0.0, 1.0);
        }
        return (currentValue / targetValue!).clamp(0.0, 1.0);
    }
  }

  /// Get progress for today (for daily goals with numeric progress)
  double getProgressToday(DateTime now) {
    if (goalType != GoalType.daily) {
      return getProgress();
    }

    if (progressType == ProgressType.completion) {
      final today = DateUtils.normalizeToDay(now);
      final lastCompleted = lastCompletedAt != null
          ? DateUtils.normalizeToDay(lastCompletedAt!)
          : null;
      return (lastCompleted == today) ? 1.0 : 0.0;
    } else if (progressType == ProgressType.numeric) {
      // Count completions today as progress toward daily target
      return todayCompletions
          .where((completion) => DateUtils.isSameDay(completion, now))
          .length
          .toDouble();
    }

    return getProgress();
  }

  /// Get the daily target for numeric daily goals
  int get dailyTarget => targetValue?.toInt() ?? 1;

  /// Get number of milestones completed
  int get completedMilestones =>
      milestones.where((m) => m.completed).length;

  /// Get days remaining until deadline (null if no deadline)
  int? getDaysRemaining(DateTime now) {
    if (deadline == null) return null;
    final diff = deadline!.difference(now);
    return diff.inDays;
  }

  /// Check if goal is overdue
  bool isOverdue(DateTime now) {
    if (deadline == null) return false;
    return now.isAfter(deadline!) && !isCompleted;
  }

  /// Get next due time (for daily goals)
  DateTime? getNextDueTime(DateTime now) {
    if (goalType == GoalType.longTerm) {
      return deadline;
    }
    // Daily goal - due at end of day
    return DateUtils.getEndOfDay(now);
  }

  Goal copyWith({
    String? id,
    String? title,
    GoalType? goalType,
    ProgressType? progressType,
    double? targetValue,
    double? currentValue,
    String? unit,
    double? percentComplete,
    List<Milestone>? milestones,
    DateTime? deadline,
    List<DateTime>? todayCompletions,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCompletedAt,
    String? completionImagePath,
    String? completionMemo,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      goalType: goalType ?? this.goalType,
      progressType: progressType ?? this.progressType,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      percentComplete: percentComplete ?? this.percentComplete,
      milestones: milestones ?? this.milestones,
      deadline: deadline ?? this.deadline,
      todayCompletions: todayCompletions ?? this.todayCompletions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      completionImagePath: completionImagePath ?? this.completionImagePath,
      completionMemo: completionMemo ?? this.completionMemo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'goalType': goalType.name,
      'progressType': progressType.name,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'percentComplete': percentComplete,
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'deadline': deadline?.toIso8601String(),
      'todayCompletions':
          todayCompletions.map((d) => d.toIso8601String()).toList(),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'completionImagePath': completionImagePath,
      'completionMemo': completionMemo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      goalType: GoalType.values.firstWhere(
        (e) => e.name == json['goalType'],
        orElse: () => GoalType.daily,
      ),
      progressType: ProgressType.values.firstWhere(
        (e) => e.name == json['progressType'],
        orElse: () => ProgressType.completion,
      ),
      targetValue: (json['targetValue'] as num?)?.toDouble(),
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String?,
      percentComplete: (json['percentComplete'] as num?)?.toDouble() ?? 0,
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((e) => Milestone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      todayCompletions: (json['todayCompletions'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          [],
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.parse(json['lastCompletedAt'] as String)
          : null,
      completionImagePath: json['completionImagePath'] as String?,
      completionMemo: json['completionMemo'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
