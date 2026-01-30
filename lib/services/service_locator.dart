import '../data/goal_repository.dart';
import '../logic/widget_update_engine.dart';
import 'widget_snapshot_service.dart';

/// Simple service locator for dependency injection
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  late final GoalRepository _goalRepository = GoalRepository();
  late final WidgetSnapshotService _widgetSnapshotService = 
      WidgetSnapshotService(_goalRepository);
  late final WidgetUpdateEngine _widgetUpdateEngine = 
      WidgetUpdateEngine(_goalRepository, _widgetSnapshotService);

  GoalRepository get goalRepository => _goalRepository;
  WidgetSnapshotService get widgetSnapshotService => _widgetSnapshotService;
  WidgetUpdateEngine get widgetUpdateEngine => _widgetUpdateEngine;
}

/// Convenience getters
final goalRepository = ServiceLocator.instance.goalRepository;
final widgetSnapshotService = ServiceLocator.instance.widgetSnapshotService;
final widgetUpdateEngine = ServiceLocator.instance.widgetUpdateEngine;
