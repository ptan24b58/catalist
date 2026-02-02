import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../domain/event.dart';
import '../utils/logger.dart';

/// Singleton service for scheduling local notifications for calendar events.
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(_localTimeZoneName()));
    } catch (_) {
      // DateTime.now().timeZoneName returns abbreviations like "CST" which
      // the timezone package doesn't recognise. Fall back to UTC.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
    AppLogger.info('NotificationService initialized');
  }

  String _localTimeZoneName() {
    try {
      return DateTime.now().timeZoneName;
    } catch (_) {
      return 'UTC';
    }
  }

  /// Schedule a reminder notification for a calendar event.
  /// Returns the notification ID used, or null if no reminder was set.
  Future<int?> scheduleReminder(CalendarEvent event) async {
    if (event.reminderMinutesBefore <= 0) return null;
    if (!_initialized) {
      AppLogger.warning('NotificationService not initialized');
      return null;
    }

    try {
      // Calculate the event datetime
      DateTime eventDateTime;
      if (event.isAllDay || event.startTime == null) {
        // For all-day events, use 9:00 AM on the event date
        eventDateTime = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
          9,
          0,
        );
      } else {
        eventDateTime = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
          event.startTime!.hour,
          event.startTime!.minute,
        );
      }

      // Subtract reminder offset
      final reminderTime = eventDateTime.subtract(
        Duration(minutes: event.reminderMinutesBefore),
      );

      // Don't schedule if the reminder time is in the past
      if (reminderTime.isBefore(DateTime.now())) return null;

      final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);
      final notificationId =
          event.id.hashCode.abs() % 2147483647; // Keep within int range

      await _plugin.zonedSchedule(
        notificationId,
        event.title,
        event.isAllDay ? 'All-day event' : _formatTimeRange(event),
        tzReminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'calendar_events',
            'Calendar Events',
            channelDescription: 'Reminders for calendar events',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );

      AppLogger.info(
          'Scheduled reminder for "${event.title}" at $reminderTime');
      return notificationId;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to schedule reminder', e, stackTrace);
      return null;
    }
  }

  /// Cancel a previously scheduled reminder.
  Future<void> cancelReminder(int? notificationId) async {
    if (notificationId == null) return;
    try {
      await _plugin.cancel(notificationId);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to cancel reminder', e, stackTrace);
    }
  }

  String _formatTimeRange(CalendarEvent event) {
    if (event.startTime == null) return '';
    final start = _formatTime(event.startTime!);
    if (event.endTime == null) return start;
    return '$start – ${_formatTime(event.endTime!)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
