import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/event.dart';
import '../utils/logger.dart';

/// Callback signature for event change events
typedef EventChangeCallback = Future<void> Function();

/// Repository for managing calendar events
class EventRepository {
  static const String _eventsKey = 'calendar_events';

  EventChangeCallback? _changeListener;

  /// Set a listener to be notified when events change
  void setChangeListener(EventChangeCallback? listener) {
    _changeListener = listener;
  }

  /// Notify listener of a change
  Future<void> _notifyChange() async {
    if (_changeListener != null) {
      await _changeListener!();
    }
  }

  /// Get all events
  Future<List<CalendarEvent>> getAllEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_eventsKey);

      if (json == null || json.isEmpty) {
        return [];
      }

      // 1MB guard
      if (json.length > 1000000) {
        AppLogger.error('Events JSON too large, potential corruption');
        return [];
      }

      final decoded = jsonDecode(json);
      if (decoded is! List) {
        AppLogger.error('Invalid events format: expected List');
        return [];
      }

      return decoded
          .map((item) {
            try {
              if (item is! Map<String, dynamic>) {
                AppLogger.warning('Invalid event format: expected Map');
                return null;
              }
              return CalendarEvent.fromJson(item);
            } catch (e, stackTrace) {
              AppLogger.warning('Failed to parse event from JSON', e);
              AppLogger.debug('Invalid event JSON: $item', e, stackTrace);
              return null;
            }
          })
          .whereType<CalendarEvent>()
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load events', e, stackTrace);
      return [];
    }
  }

  /// Get events for a specific date
  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final events = await getAllEvents();
    return events.where((e) {
      return e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day;
    }).toList()
      ..sort((a, b) {
        if (a.isAllDay && !b.isAllDay) return -1;
        if (!a.isAllDay && b.isAllDay) return 1;
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        final aMinutes = a.startTime!.hour * 60 + a.startTime!.minute;
        final bMinutes = b.startTime!.hour * 60 + b.startTime!.minute;
        return aMinutes.compareTo(bMinutes);
      });
  }

  /// Get events grouped by date for a given month (for dot indicators)
  Future<Map<DateTime, List<CalendarEvent>>> getEventsForMonth(
      DateTime month) async {
    final events = await getAllEvents();
    final Map<DateTime, List<CalendarEvent>> grouped = {};

    for (final event in events) {
      if (event.date.year == month.year && event.date.month == month.month) {
        final dateKey =
            DateTime(event.date.year, event.date.month, event.date.day);
        grouped.putIfAbsent(dateKey, () => []).add(event);
      }
    }

    return grouped;
  }

  /// Save an event (create or update)
  Future<void> saveEvent(CalendarEvent event) async {
    try {
      final events = await getAllEvents();
      final index = events.indexWhere((e) => e.id == event.id);

      if (index >= 0) {
        events[index] = event;
      } else {
        events.add(event);
      }

      await _saveAllEvents(events);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save event', e, stackTrace);
      rethrow;
    }
  }

  /// Delete an event
  Future<void> deleteEvent(String id) async {
    try {
      final events = await getAllEvents();
      events.removeWhere((e) => e.id == id);
      await _saveAllEvents(events);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete event', e, stackTrace);
      rethrow;
    }
  }

  /// Get an event by ID
  Future<CalendarEvent?> getEventById(String id) async {
    final events = await getAllEvents();
    try {
      return events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveAllEvents(List<CalendarEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
      await prefs.setString(_eventsKey, encoded);
      await _notifyChange();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save events to storage', e, stackTrace);
      rethrow;
    }
  }
}
