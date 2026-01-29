import '../data/goal_repository.dart';

/// Simple service locator for dependency injection
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  late final GoalRepository _goalRepository = GoalRepository();

  GoalRepository get goalRepository => _goalRepository;
}

/// Convenience getters
final goalRepository = ServiceLocator.instance.goalRepository;
