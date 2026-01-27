import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../services/service_locator.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/progress_formatter.dart';
import '../utils/snackbar_helper.dart';
import '../utils/gamification.dart';
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
    final totalXP = Gamification.calculateTotalXP(_goals);
    final level = Gamification.calculateLevel(totalXP);
    final levelProgress = Gamification.getLevelProgress(totalXP);
    final xpInLevel = Gamification.xpInCurrentLevel(totalXP);
    const xpNeeded = Gamification.xpPerLevel;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildExperienceBanner(
                  level: level,
                  totalXP: totalXP,
                  levelProgress: levelProgress,
                  xpInLevel: xpInLevel,
                  xpNeeded: xpNeeded,
                ),
                _buildFilterButtons(),
                Expanded(
                  child: _filteredGoals.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _filteredGoals.length,
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemBuilder: (context, index) {
                            final goal = _filteredGoals[index];
                            return _buildGoalCard(goal);
                          },
                        ),
                ),
              ],
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

  Widget _buildExperienceBanner({
    required int level,
    required int totalXP,
    required double levelProgress,
    required int xpInLevel,
    required int xpNeeded,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final goldColor = Theme.of(context).colorScheme.tertiary;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: _buildBannerDecoration(primaryColor, goldColor),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLevelInfo(level, xpInLevel, xpNeeded, primaryColor)),
                const SizedBox(width: 16),
                _buildTotalXPBadge(totalXP, primaryColor),
              ],
            ),
            const SizedBox(height: 24),
            _buildProgressBar(levelProgress, primaryColor, goldColor),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildBannerDecoration(Color primaryColor, Color goldColor) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withValues(alpha: 0.3),
          primaryColor.withValues(alpha: 0.2),
          goldColor.withValues(alpha: 0.2),
          goldColor.withValues(alpha: 0.1),
        ],
        stops: const [0.0, 0.4, 0.6, 1.0],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: primaryColor.withValues(alpha: 0.25),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.2),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildLevelInfo(int level, int xpInLevel, int xpNeeded, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            'LEVEL $level',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Experience',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$xpInLevel',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                height: 1.0,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '/ $xpNeeded XP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTotalXPBadge(int totalXP, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              letterSpacing: 0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalXP',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'XP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double levelProgress, Color primaryColor, Color goldColor) {
    return Stack(
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        FractionallySizedBox(
          widthFactor: levelProgress,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, goldColor]),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton('All', GoalFilter.all),
          ),
          Expanded(
            child: _buildFilterButton('Daily', GoalFilter.daily),
          ),
          Expanded(
            child: _buildFilterButton('Long-term', GoalFilter.longTerm),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, GoalFilter filter) {
    final isSelected = _filter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _filter = filter);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = switch (_filter) {
      GoalFilter.all => 'No goals yet',
      GoalFilter.daily => 'No daily goals yet',
      GoalFilter.longTerm => 'No long-term goals yet',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
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
