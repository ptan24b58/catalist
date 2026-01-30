import '../domain/mascot_state.dart';

/// Represents a goal to display in the widget
class TopGoal {
  final String id;
  final String title;
  final double progress;
  final String goalType;
  final String progressType;
  final int? nextDueEpoch;
  final double urgency;
  final String? progressLabel;

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
      urgency: (json['urgency'] as num?)?.toDouble() ?? 0.0,
      progressLabel: json['progressLabel'] as String?,
    );
  }
}

/// Complete widget snapshot containing all data needed to render the widget
class WidgetSnapshot {
  final int version;
  final int generatedAt;
  final TopGoal? topGoal;
  final MascotState mascot;
  final String cta;
  final String backgroundStatus;
  final String backgroundTimeBand;
  final int backgroundVariant;

  const WidgetSnapshot({
    required this.version,
    required this.generatedAt,
    this.topGoal,
    required this.mascot,
    required this.cta,
    required this.backgroundStatus,
    required this.backgroundTimeBand,
    required this.backgroundVariant,
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
      cta: json['cta'] as String,
      backgroundStatus: json['backgroundStatus'] as String,
      backgroundTimeBand: json['backgroundTimeBand'] as String,
      backgroundVariant: json['backgroundVariant'] as int,
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
