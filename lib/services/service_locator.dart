import '../data/event_repository.dart';
import '../data/goal_repository.dart';
import '../data/collection_repository.dart';
import '../logic/widget_update_engine.dart';
import 'widget_snapshot_service.dart';

/// Simple service locator for dependency injection
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  late final EventRepository _eventRepository = EventRepository();
  late final GoalRepository _goalRepository = GoalRepository();
  late final CollectionRepository _collectionRepository = CollectionRepository();
  late final WidgetSnapshotService _widgetSnapshotService =
      WidgetSnapshotService(_goalRepository);
  late final WidgetUpdateEngine _widgetUpdateEngine =
      WidgetUpdateEngine(_goalRepository, _widgetSnapshotService);

  EventRepository get eventRepository => _eventRepository;
  GoalRepository get goalRepository => _goalRepository;
  CollectionRepository get collectionRepository => _collectionRepository;
  WidgetSnapshotService get widgetSnapshotService => _widgetSnapshotService;
  WidgetUpdateEngine get widgetUpdateEngine => _widgetUpdateEngine;
}

/// Convenience getters
final eventRepository = ServiceLocator.instance.eventRepository;
final goalRepository = ServiceLocator.instance.goalRepository;
final collectionRepository = ServiceLocator.instance.collectionRepository;
final widgetSnapshotService = ServiceLocator.instance.widgetSnapshotService;
final widgetUpdateEngine = ServiceLocator.instance.widgetUpdateEngine;
