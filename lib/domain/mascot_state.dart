/// Mascot emotional state
enum MascotEmotion {
  happy,
  neutral,
  worried,
  sad,
  celebrate,
}

/// Mascot state model - finite state machine
class MascotState {
  final MascotEmotion emotion;
  final int frameIndex;
  final DateTime? expiresAt; // For temporary states like celebrate

  const MascotState({
    required this.emotion,
    this.frameIndex = 0,
    this.expiresAt,
  });

  /// Check if this state has expired and should revert
  bool isExpired(DateTime now) {
    if (expiresAt == null) return false;
    return now.isAfter(expiresAt!);
  }

  /// Get the current valid state (reverting if expired)
  MascotState resolve(DateTime now, MascotEmotion defaultEmotion) {
    if (isExpired(now)) {
      return MascotState(
        emotion: defaultEmotion,
        frameIndex: 0,
      );
    }
    return this;
  }

  MascotState copyWith({
    MascotEmotion? emotion,
    int? frameIndex,
    DateTime? expiresAt,
  }) {
    return MascotState(
      emotion: emotion ?? this.emotion,
      frameIndex: frameIndex ?? this.frameIndex,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion.name,
      'frameIndex': frameIndex,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
    };
  }

  factory MascotState.fromJson(Map<String, dynamic> json) {
    return MascotState(
      emotion: MascotEmotion.values.firstWhere(
        (e) => e.name == json['emotion'],
        orElse: () => MascotEmotion.neutral,
      ),
      frameIndex: json['frameIndex'] as int? ?? 0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int)
          : null,
    );
  }
}
