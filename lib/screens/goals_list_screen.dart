import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../services/service_locator.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/progress_formatter.dart';
import '../utils/snackbar_helper.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';

enum GoalFilter { all, daily, longTerm }

class GoalsListScreen extends StatefulWidget {
  const GoalsListScreen({super.key});

  @override
  State<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen> {
  List<Goal> _goals = [];
  bool _isLoading = true;
  GoalFilter _filter = GoalFilter.all;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  List<Goal> get _filteredGoals {
    switch (_filter) {
      case GoalFilter.all:
        return _goals;
      case GoalFilter.daily:
        return _goals.where((g) => g.goalType == GoalType.daily).toList();
      case GoalFilter.longTerm:
        return _goals.where((g) => g.goalType == GoalType.longTerm).toList();
    }
  }

  Future<void> _loadGoals() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final goals = await goalRepository.getAllGoals();
      if (mounted) {
        setState(() {
          _goals = goals;
          _isLoading = false;
        });
      }
      // Snapshot automatically updated by WidgetUpdateEngine when goals change
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load goals', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, AppConstants.errorLoadFailed);
      }
    }
  }

  Future<void> _logProgress(Goal goal) async {
    final now = DateTime.now();
    try {
      if (goal.goalType == GoalType.daily) {
        await goalRepository.logDailyCompletion(goal.id, now);
        // Snapshot automatically updated by WidgetUpdateEngine
      } else {
        // For long-term goals, navigate to detail for more complex progress updates
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalDetailScreen(goal: goal),
            ),
          );
        }
        await _loadGoals();
        return;
      }
      await _loadGoals();

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          AppConstants.successProgressLogged,
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to log progress', e, stackTrace);
      if (mounted) {
        SnackBarHelper.showError(
          context,
          '${AppConstants.errorLogProgress}: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await goalRepository.deleteGoal(goal.id);
        // Snapshot automatically updated by WidgetUpdateEngine
        await _loadGoals();
      } catch (e, stackTrace) {
        AppLogger.error('Failed to delete goal', e, stackTrace);
        if (mounted) {
          SnackBarHelper.showError(
            context,
            '${AppConstants.errorDeleteGoal}: ${e.toString()}',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterTabs(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredGoals.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredGoals.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemBuilder: (context, index) {
                    final goal = _filteredGoals[index];
                    return _buildGoalCard(goal);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddGoalScreen(),
            ),
          );
          await _loadGoals();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', GoalFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Daily', GoalFilter.daily),
          const SizedBox(width: 8),
          _buildFilterChip('Long-term', GoalFilter.longTerm),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, GoalFilter filter) {
    final isSelected = _filter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = filter);
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildEmptyState() {
    final message = switch (_filter) {
      GoalFilter.all => 'No goals yet',
      GoalFilter.daily => 'No daily goals yet',
      GoalFilter.longTerm => 'No long-term goals yet',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first goal',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    final now = DateTime.now();
    final progress = goal.getProgress();
    final isCompleted = goal.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalDetailScreen(goal: goal),
            ),
          );
          await _loadGoals();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(goal, isCompleted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _buildGoalTypeBadge(goal),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildSubtitle(goal, now),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProgressIndicator(goal, progress),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ProgressFormatter.getDetailedProgressLabel(goal, now: now),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCompleted && goal.goalType == GoalType.daily)
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => _logProgress(goal),
                          tooltip: 'Log Progress',
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteGoal(goal),
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Goal goal, bool isCompleted) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: isCompleted
          ? Theme.of(context).colorScheme.tertiary
          : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
      child: Icon(
        isCompleted ? Icons.check : _getGoalIcon(goal),
        color: isCompleted
            ? Colors.white
            : Theme.of(context).colorScheme.secondary,
        size: 20,
      ),
    );
  }

  IconData _getGoalIcon(Goal goal) {
    if (goal.goalType == GoalType.daily) {
      return Icons.repeat;
    }
    return switch (goal.progressType) {
      ProgressType.milestones => Icons.checklist,
      ProgressType.percentage => Icons.pie_chart_outline,
      ProgressType.numeric => Icons.trending_up,
      _ => Icons.flag_outlined,
    };
  }

  Widget _buildGoalTypeBadge(Goal goal) {
    final isDaily = goal.goalType == GoalType.daily;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDaily
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isDaily ? 'Daily' : 'Long-term',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDaily
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }

  Widget _buildSubtitle(Goal goal, DateTime now) {
    if (goal.goalType == GoalType.daily) {
      return Row(
        children: [
          Icon(
            Icons.local_fire_department,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '${goal.currentStreak} day streak',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    // Long-term goal
    if (goal.deadline != null) {
      final daysRemaining = goal.getDaysRemaining(now);
      final isOverdue = goal.isOverdue(now);
      return Row(
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.calendar_today,
            size: 14,
            color: isOverdue
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            isOverdue
                ? 'Overdue'
                : daysRemaining == 0
                    ? 'Due today'
                    : '$daysRemaining days remaining',
            style: TextStyle(
              fontSize: 12,
              color: isOverdue
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    return Text(
      'No deadline',
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildProgressIndicator(Goal goal, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          goal.isCompleted
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
