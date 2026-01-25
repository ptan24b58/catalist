import '../data/goal_repository.dart';
import 'widget_snapshot_service.dart';

/// Simple service locator for dependency injection
/// Provides singleton instances of services throughout the app
class ServiceLocator {
  ServiceLocator._(); // Private constructor

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  // Lazy-initialized singletons
  GoalRepository? _goalRepository;
  WidgetSnapshotService? _widgetSnapshotService;

  /// Get the GoalRepository singleton
  GoalRepository get goalRepository {
    _goalRepository ??= GoalRepository();
    return _goalRepository!;
  }

  /// Get the WidgetSnapshotService singleton
  WidgetSnapshotService get widgetSnapshotService {
    _widgetSnapshotService ??= WidgetSnapshotService(goalRepository);
    return _widgetSnapshotService!;
  }

  /// Reset all services (useful for testing)
  void reset() {
    _goalRepository = null;
    _widgetSnapshotService = null;
  }

  /// Register a custom GoalRepository (for testing)
  void registerGoalRepository(GoalRepository repository) {
    _goalRepository = repository;
    // Reset dependent services
    _widgetSnapshotService = null;
  }

  /// Register a custom WidgetSnapshotService (for testing)
  void registerWidgetSnapshotService(WidgetSnapshotService service) {
    _widgetSnapshotService = service;
  }
}

/// Convenience getters for cleaner access
GoalRepository get goalRepository => ServiceLocator.instance.goalRepository;
WidgetSnapshotService get widgetSnapshotService =>
    ServiceLocator.instance.widgetSnapshotService;
