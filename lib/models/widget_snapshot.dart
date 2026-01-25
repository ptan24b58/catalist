import '../domain/mascot_state.dart';

/// Widget snapshot model for native widget display
class WidgetSnapshot {
  final int version;
  final int generatedAt;
  final TopGoal? topGoal;
  final MascotState mascot;

  const WidgetSnapshot({
    required this.version,
    required this.generatedAt,
    this.topGoal,
    required this.mascot,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'generatedAt': generatedAt,
      'topGoal': topGoal?.toJson(),
      'mascot': mascot.toJson(),
    };
  }

  factory WidgetSnapshot.fromJson(Map<String, dynamic> json) {
    return WidgetSnapshot(
      version: json['version'] as int,
      generatedAt: json['generatedAt'] as int,
      topGoal: json['topGoal'] != null
          ? TopGoal.fromJson(json['topGoal'] as Map<String, dynamic>)
          : null,
      mascot: MascotState.fromJson(json['mascot'] as Map<String, dynamic>),
    );
  }

  WidgetSnapshot copyWith({
    int? version,
    int? generatedAt,
    TopGoal? topGoal,
    MascotState? mascot,
  }) {
    return WidgetSnapshot(
      version: version ?? this.version,
      generatedAt: generatedAt ?? this.generatedAt,
      topGoal: topGoal ?? this.topGoal,
      mascot: mascot ?? this.mascot,
    );
  }
}

/// Top goal model for widget display
class TopGoal {
  final String id;
  final String title;
  final double progress;
  final String goalType; // 'daily' or 'longTerm'
  final String progressType; // 'completion', 'percentage', 'milestones', 'numeric'
  final int? nextDueEpoch;
  final double urgency;
  final String? progressLabel; // Human-readable progress (e.g., "3/5 milestones")

  const TopGoal({
    required this.id,
    required this.title,
    required this.progress,
    required this.goalType,
    required this.progressType,
    this.nextDueEpoch,
    required this.urgency,
    this.progressLabel,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'progress': progress,
      'goalType': goalType,
      'progressType': progressType,
      'nextDueEpoch': nextDueEpoch,
      'urgency': urgency,
      'progressLabel': progressLabel,
    };
  }

  factory TopGoal.fromJson(Map<String, dynamic> json) {
    return TopGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      progress: (json['progress'] as num).toDouble(),
      goalType: json['goalType'] as String,
      progressType: json['progressType'] as String,
      nextDueEpoch: json['nextDueEpoch'] as int?,
      urgency: (json['urgency'] as num).toDouble(),
      progressLabel: json['progressLabel'] as String?,
    );
  }
}
