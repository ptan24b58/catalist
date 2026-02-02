/// A collection item captured by the user - from goal completions, travel, life events, etc.
class CollectionItem {
  final String id;
  final String title;
  final String? memo;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime eventDate;

  /// Set when item is auto-created from goal completion
  final String? linkedGoalId;

  /// Denormalized so it survives goal deletion
  final String? linkedGoalTitle;

  const CollectionItem({
    required this.id,
    required this.title,
    this.memo,
    this.imagePath,
    required this.createdAt,
    required this.eventDate,
    this.linkedGoalId,
    this.linkedGoalTitle,
  });

  bool get isGoalLinked => linkedGoalId != null;

  CollectionItem copyWith({
    String? id,
    String? title,
    String? memo,
    String? imagePath,
    DateTime? createdAt,
    DateTime? eventDate,
    String? linkedGoalId,
    String? linkedGoalTitle,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      eventDate: eventDate ?? this.eventDate,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      linkedGoalTitle: linkedGoalTitle ?? this.linkedGoalTitle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'memo': memo,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'eventDate': eventDate.toIso8601String(),
      'linkedGoalId': linkedGoalId,
      'linkedGoalTitle': linkedGoalTitle,
    };
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as String,
      title: json['title'] as String,
      memo: json['memo'] as String?,
      imagePath: json['imagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      eventDate: DateTime.parse(json['eventDate'] as String),
      linkedGoalId: json['linkedGoalId'] as String?,
      linkedGoalTitle: json['linkedGoalTitle'] as String?,
    );
  }
}
