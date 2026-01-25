import '../data/goal_repository.dart';
import 'widget_snapshot_service.dart';

/// Simple service locator for dependency injection
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  late final GoalRepository _goalRepository = GoalRepository();
  late final WidgetSnapshotService _widgetSnapshotService =
      WidgetSnapshotService(_goalRepository);

  GoalRepository get goalRepository => _goalRepository;
  WidgetSnapshotService get widgetSnapshotService => _widgetSnapshotService;
}

/// Convenience getters
final goalRepository = ServiceLocator.instance.goalRepository;
final widgetSnapshotService = ServiceLocator.instance.widgetSnapshotService;
