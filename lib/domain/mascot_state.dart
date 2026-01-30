import '../utils/constants.dart';

/// Mascot emotional states
enum MascotEmotion {
  happy,
  neutral,
  worried,
  sad,
  celebrate,
}

/// Represents the current state of the mascot
class MascotState {
  final MascotEmotion emotion;
  final DateTime? expiresAt;

  const MascotState({
    required this.emotion,
    this.expiresAt,
  });

  /// Create a celebration state that expires after 5 minutes
  factory MascotState.celebrate(DateTime now) {
    return MascotState(
      emotion: MascotEmotion.celebrate,
      expiresAt: now.add(AppConstants.celebrateDuration),
    );
  }

  /// Check if the current emotion has expired
  bool isExpired(DateTime now) {
    if (expiresAt == null) return false;
    return now.isAfter(expiresAt!);
  }

  MascotState copyWith({
    MascotEmotion? emotion,
    DateTime? expiresAt,
  }) {
    return MascotState(
      emotion: emotion ?? this.emotion,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion.name,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory MascotState.fromJson(Map<String, dynamic> json) {
    return MascotState(
      emotion: MascotEmotion.values.firstWhere(
        (e) => e.name == json['emotion'],
        orElse: () => MascotEmotion.neutral,
      ),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MascotState &&
        other.emotion == emotion &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => emotion.hashCode ^ expiresAt.hashCode;
}
