import '../domain/mascot_state.dart';

/// Widget snapshot model for native widget display
class WidgetSnapshot {
  final int version;
  final int generatedAt;
  final TopGoal? topGoal;
  final MascotState mascot;
  final String? cta; // Dynamic call-to-action message
  /// Background status for gradient/pattern (celebrate, on_track, behind, urgent, empty)
  final String? backgroundStatus;
  /// Time band for rotation (dawn, day, dusk, night)
  final String? backgroundTimeBand;
  /// Variant 1–3: which of the multiple backgrounds to use for this (status, time)
  final int? backgroundVariant;

  const WidgetSnapshot({
    required this.version,
    required this.generatedAt,
    this.topGoal,
    required this.mascot,
    this.cta,
    this.backgroundStatus,
    this.backgroundTimeBand,
    this.backgroundVariant,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'generatedAt': generatedAt,
      'topGoal': topGoal?.toJson(),
      'mascot': mascot.toJson(),
      'cta': cta,
      'backgroundStatus': backgroundStatus,
      'backgroundTimeBand': backgroundTimeBand,
      'backgroundVariant': backgroundVariant,
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
      cta: json['cta'] as String?,
      backgroundStatus: json['backgroundStatus'] as String?,
      backgroundTimeBand: json['backgroundTimeBand'] as String?,
      backgroundVariant: json['backgroundVariant'] as int?,
    );
  }

  WidgetSnapshot copyWith({
    int? version,
    int? generatedAt,
    TopGoal? topGoal,
    MascotState? mascot,
    String? cta,
    String? backgroundStatus,
    String? backgroundTimeBand,
    int? backgroundVariant,
  }) {
    return WidgetSnapshot(
      version: version ?? this.version,
      generatedAt: generatedAt ?? this.generatedAt,
      topGoal: topGoal ?? this.topGoal,
      mascot: mascot ?? this.mascot,
      cta: cta ?? this.cta,
      backgroundStatus: backgroundStatus ?? this.backgroundStatus,
      backgroundTimeBand: backgroundTimeBand ?? this.backgroundTimeBand,
      backgroundVariant: backgroundVariant ?? this.backgroundVariant,
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
