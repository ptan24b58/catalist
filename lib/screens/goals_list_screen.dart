import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../services/service_locator.dart';
import '../utils/logger.dart';
import '../utils/progress_formatter.dart';
import '../utils/gamification.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_helper.dart';
import '../widgets/gamification/level_badge.dart';
import '../widgets/gamification/streak_badge.dart';
import '../widgets/gamification/crown_icon.dart';
import '../widgets/gamification/xp_burst.dart';
import '../widgets/celebration_overlay.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';
import 'memories_screen.dart';

enum GoalFilter { all, daily, longTerm }

class GoalsListScreen extends StatefulWidget {
  const GoalsListScreen({super.key});

  @override
  State<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen> {
  List<Goal> _goals = [];
  int _lifetimeXp = 0;
  int _perfectDayStreak = 0;
  bool _isLoading = true;
  GoalFilter _filter = GoalFilter.all;
  final GlobalKey<XPBurstOverlayState> _xpOverlayKey = GlobalKey();

  // Cached computed values to avoid repeated calculations
  List<Goal>? _cachedFilteredGoals;
  GoalFilter? _lastFilter;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  void _invalidateCache() {
    _cachedFilteredGoals = null;
  }

  List<Goal> get _filteredGoals {
    if (_cachedFilteredGoals != null && _lastFilter == _filter) {
      return _cachedFilteredGoals!;
    }
    _lastFilter = _filter;
    _cachedFilteredGoals = switch (_filter) {
      GoalFilter.all => _goals,
      GoalFilter.daily => _goals.where((g) => g.goalType == GoalType.daily).toList(),
      GoalFilter.longTerm => _goals.where((g) => g.goalType == GoalType.longTerm).toList(),
    };
    return _cachedFilteredGoals!;
  }

  Future<void> _loadGoals() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final goals = await goalRepository.getAllGoals();
      final xp = await goalRepository.getLifetimeEarnedXp();
      final streak = await goalRepository.getPerfectDayStreak();
      if (mounted) {
        setState(() {
          _goals = goals;
          _lifetimeXp = xp;
          _perfectDayStreak = streak;
          _isLoading = false;
          _invalidateCache();
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load goals', e, stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logProgress(Goal goal) async {
    final now = DateTime.now();
    try {
      if (goal.goalType == GoalType.daily) {
        await goalRepository.logDailyCompletion(goal.id, now);
        // Show XP burst
        _xpOverlayKey.currentState?.showXPBurst(Gamification.xpPerDailyCompletion);
        await _loadGoals();
        if (mounted) showCelebrationOverlay(context);
      } else {
        // For long-term goals, navigate to detail for more complex progress updates
        if (mounted) {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => GoalDetailScreen(goal: goal),
            ),
          );
          await _loadGoals();
          
          // Show XP burst and celebration if returned from completing a long-term goal
          if (result != null && result['celebrate'] == true && mounted) {
            final xp = result['xp'] as int? ?? 20;
            _xpOverlayKey.currentState?.showXPBurst(xp);
            showCelebrationOverlay(context);
          }
        }
        return;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to log progress', e, stackTrace);
    }
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await DialogHelper.showDeleteGoalConfirmation(
      context,
      goalTitle: goal.title,
    );
    if (confirmed) {
      try {
        await goalRepository.deleteGoal(goal.id);
        await _loadGoals();
      } catch (e, stackTrace) {
        AppLogger.error('Failed to delete goal', e, stackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalXP = _lifetimeXp;
    final level = Gamification.calculateLevel(totalXP);
    final levelProgress = Gamification.getLevelProgress(totalXP);
    final xpInLevel = Gamification.xpInCurrentLevel(totalXP);

    return XPBurstOverlay(
      key: _xpOverlayKey,
      child: Scaffold(
        body: SafeArea(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Enhanced Level Banner
                  LevelBanner(
                    level: level,
                    totalXP: totalXP,
                    xpInLevel: xpInLevel,
                    levelProgress: levelProgress,
                  ),
                  // Perfect day streak and accomplishments button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          StreakBadge(streak: _perfectDayStreak, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _perfectDayStreak == 1 ? 'perfect day' : 'perfect days',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          // Accomplishments gallery button
                          Material(
                            color: AppColors.xpGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MemoriesScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      size: 18,
                                      color: AppColors.xpGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Memories',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.xpGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
      ),
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
          if (_filter != filter) {
            setState(() {
              _filter = filter;
              _cachedFilteredGoals = null; // Invalidate filter cache
            });
          }
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // More rounded (Duolingo-style)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4), // Bolder shadow
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                builder: (context) => GoalDetailScreen(goal: goal),
              ),
            );
            await _loadGoals();
            
            // Show XP burst and celebration if returned from completing a long-term goal
            if (result != null && result['celebrate'] == true && mounted) {
              final xp = result['xp'] as int? ?? 20;
              _xpOverlayKey.currentState?.showXPBurst(xp);
              showCelebrationOverlay(context);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20), // Larger padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusIcon(goal, isCompleted),
                    const SizedBox(width: 16),
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(width: 8),
                                const CrownBadge(size: 28),
                              ] else ...[
                                _buildGoalTypeBadge(goal),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildSubtitle(goal, now),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProgressIndicator(goal, progress),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ProgressFormatter.getDetailedProgressLabel(goal, now: now),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isCompleted && goal.goalType == GoalType.daily)
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.xpGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () => _logProgress(goal),
                              tooltip: 'Complete Today',
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.xpGreen,
                                minimumSize: const Size(44, 44),
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteGoal(goal),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
          const Icon(
            Icons.local_fire_department,
            size: 14,
            color: AppColors.streakFlameOrange,
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
    final isCompleted = goal.isCompleted;
    final progressColor = isCompleted
        ? AppColors.xpGreen
        : Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5), // More rounded
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 10, // Thicker (was 8)
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
      ),
    );
  }
}
