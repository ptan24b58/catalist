import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Category for calendar events, each with its own accent color.
enum EventCategory {
  personal,
  work,
  health,
  social,
  other;

  Color get color {
    switch (this) {
      case EventCategory.personal:
        return AppColors.primary;
      case EventCategory.work:
        return AppColors.catBlue;
      case EventCategory.health:
        return AppColors.xpGreen;
      case EventCategory.social:
        return AppColors.catGold;
      case EventCategory.other:
        return AppColors.textSecondary;
    }
  }

  String get displayName {
    switch (this) {
      case EventCategory.personal:
        return 'Personal';
      case EventCategory.work:
        return 'Work';
      case EventCategory.health:
        return 'Health';
      case EventCategory.social:
        return 'Social';
      case EventCategory.other:
        return 'Other';
    }
  }
}

/// Reminder offset options before an event.
enum ReminderOption {
  none(0, 'None'),
  fiveMin(5, '5 min'),
  fifteenMin(15, '15 min'),
  thirtyMin(30, '30 min'),
  oneHour(60, '1 hour'),
  oneDay(1440, '1 day');

  final int minutes;
  final String displayName;
  const ReminderOption(this.minutes, this.displayName);
}

/// A calendar event created by the user.
class CalendarEvent {
  final String id;
  final String title;
  final String? notes;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isAllDay;
  final EventCategory category;
  final int reminderMinutesBefore;
  final int? notificationId;
  final DateTime createdAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.notes,
    required this.date,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.category = EventCategory.personal,
    this.reminderMinutesBefore = 0,
    this.notificationId,
    required this.createdAt,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isAllDay,
    EventCategory? category,
    int? reminderMinutesBefore,
    int? notificationId,
    DateTime? createdAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      category: category ?? this.category,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'date': date.toIso8601String(),
      'startTime': startTime != null
          ? {'hour': startTime!.hour, 'minute': startTime!.minute}
          : null,
      'endTime': endTime != null
          ? {'hour': endTime!.hour, 'minute': endTime!.minute}
          : null,
      'isAllDay': isAllDay,
      'category': category.name,
      'reminderMinutesBefore': reminderMinutesBefore,
      'notificationId': notificationId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] != null
          ? TimeOfDay(
              hour: (json['startTime'] as Map<String, dynamic>)['hour'] as int,
              minute:
                  (json['startTime'] as Map<String, dynamic>)['minute'] as int,
            )
          : null,
      endTime: json['endTime'] != null
          ? TimeOfDay(
              hour: (json['endTime'] as Map<String, dynamic>)['hour'] as int,
              minute:
                  (json['endTime'] as Map<String, dynamic>)['minute'] as int,
            )
          : null,
      isAllDay: json['isAllDay'] as bool? ?? false,
      category: EventCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => EventCategory.personal,
      ),
      reminderMinutesBefore: json['reminderMinutesBefore'] as int? ?? 0,
      notificationId: json['notificationId'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
