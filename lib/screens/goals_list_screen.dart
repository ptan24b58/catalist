import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../data/goal_repository.dart';
import '../widget_snapshot.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';
import 'widget_preview_screen.dart';
import '../utils/logger.dart';

enum GoalFilter { all, daily, longTerm }

class GoalsListScreen extends StatefulWidget {
  const GoalsListScreen({super.key});

  @override
  State<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen>
    with SingleTickerProviderStateMixin {
  final GoalRepository _repository = GoalRepository();
  final WidgetSnapshotService _snapshotService = WidgetSnapshotService();
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
      final goals = await _repository.getAllGoals();
      if (mounted) {
        setState(() {
          _goals = goals;
          _isLoading = false;
        });
      }
      await _snapshotService.generateSnapshot();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load goals', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load goals'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _logProgress(Goal goal) async {
    try {
      if (goal.goalType == GoalType.daily) {
        await _repository.logDailyCompletion(goal.id, DateTime.now());
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
      await _snapshotService.generateSnapshot(isCelebration: true);
      await _loadGoals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress logged!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to log progress', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log progress: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
        await _repository.deleteGoal(goal.id);
        await _snapshotService.generateSnapshot();
        await _loadGoals();
      } catch (e, stackTrace) {
        AppLogger.error('Failed to delete goal', e, stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete goal: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WidgetPreviewScreen(),
                ),
              );
            },
            tooltip: 'View Widget Preview',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _snapshotService.generateSnapshot();
              await _loadGoals();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Widget updated')),
                );
              }
            },
            tooltip: 'Refresh Widget',
          ),
        ],
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
    String message;
    switch (_filter) {
      case GoalFilter.all:
        message = 'No goals yet';
        break;
      case GoalFilter.daily:
        message = 'No daily goals yet';
        break;
      case GoalFilter.longTerm:
        message = 'No long-term goals yet';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 64,
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first goal',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
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
                  _buildProgressLabel(goal, progress),
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
    switch (goal.progressType) {
      case ProgressType.milestones:
        return Icons.checklist;
      case ProgressType.percentage:
        return Icons.pie_chart_outline;
      case ProgressType.numeric:
        return Icons.trending_up;
      default:
        return Icons.flag_outlined;
    }
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    } else {
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
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
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
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      } else {
        return Text(
          'No deadline',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        );
      }
    }
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

  Widget _buildProgressLabel(Goal goal, double progress) {
    String label;
    switch (goal.progressType) {
      case ProgressType.completion:
        label = goal.isCompleted ? 'Completed' : 'Not completed';
        break;
      case ProgressType.percentage:
        label = '${goal.percentComplete.toInt()}%';
        break;
      case ProgressType.milestones:
        label = '${goal.completedMilestones}/${goal.milestones.length} milestones';
        break;
      case ProgressType.numeric:
        final unit = goal.unit ?? '';
        if (goal.goalType == GoalType.daily) {
          final todayProgress = goal.getProgressToday(DateTime.now()).toInt();
          label = '$todayProgress/${goal.dailyTarget} $unit today';
        } else {
          label = '${goal.currentValue.toStringAsFixed(0)}/${goal.targetValue?.toStringAsFixed(0) ?? '?'} $unit';
        }
        break;
    }
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}
