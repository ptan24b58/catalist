import '../data/event_repository.dart';
import '../data/goal_repository.dart';
import '../data/memory_repository.dart';
import '../logic/widget_update_engine.dart';
import 'widget_snapshot_service.dart';

/// Simple service locator for dependency injection
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  late final EventRepository _eventRepository = EventRepository();
  late final GoalRepository _goalRepository = GoalRepository();
  late final MemoryRepository _memoryRepository = MemoryRepository();
  late final WidgetSnapshotService _widgetSnapshotService =
      WidgetSnapshotService(_goalRepository);
  late final WidgetUpdateEngine _widgetUpdateEngine =
      WidgetUpdateEngine(_goalRepository, _widgetSnapshotService);

  EventRepository get eventRepository => _eventRepository;
  GoalRepository get goalRepository => _goalRepository;
  MemoryRepository get memoryRepository => _memoryRepository;
  WidgetSnapshotService get widgetSnapshotService => _widgetSnapshotService;
  WidgetUpdateEngine get widgetUpdateEngine => _widgetUpdateEngine;
}

/// Convenience getters
final eventRepository = ServiceLocator.instance.eventRepository;
final goalRepository = ServiceLocator.instance.goalRepository;
final memoryRepository = ServiceLocator.instance.memoryRepository;
final widgetSnapshotService = ServiceLocator.instance.widgetSnapshotService;
final widgetUpdateEngine = ServiceLocator.instance.widgetUpdateEngine;
