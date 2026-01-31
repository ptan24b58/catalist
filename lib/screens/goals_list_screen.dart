import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/goal.dart';
import '../services/service_locator.dart';
import '../utils/logger.dart';
import '../utils/progress_formatter.dart';
import '../utils/gamification.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_helper.dart';
import '../widgets/gamification/streak_badge.dart';
import '../widgets/gamification/crown_icon.dart';
import '../widgets/gamification/xp_burst.dart';
import '../widgets/celebration_overlay.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';

enum GoalFilter { all, daily, longTerm, completed }

class GoalsListScreen extends StatefulWidget {
  const GoalsListScreen({super.key});

  @override
  State<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen>
    with TickerProviderStateMixin {
  List<Goal> _goals = [];
  int _lifetimeXp = 0;
  int _perfectDayStreak = 0;
  bool _isLoading = true;
  GoalFilter _filter = GoalFilter.all;
  final GlobalKey<XPBurstOverlayState> _xpOverlayKey = GlobalKey();

  // Cached computed values to avoid repeated calculations
  List<Goal>? _cachedFilteredGoals;
  GoalFilter? _lastFilter;

  // Staggered list animation
  bool _hasAnimatedIn = false;

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
      GoalFilter.all => _goals.where((g) => !g.isCompleted).toList(),
      GoalFilter.daily =>
        _goals.where((g) => g.goalType == GoalType.daily && !g.isCompleted).toList(),
      GoalFilter.longTerm =>
        _goals.where((g) => g.goalType == GoalType.longTerm && !g.isCompleted).toList(),
      GoalFilter.completed => _goals.where((g) => g.isCompleted).toList(),
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
          _hasAnimatedIn = false;
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
        HapticFeedback.heavyImpact();
        final wasCompleted = goal.isCompleted;
        final updated = await goalRepository.logDailyCompletion(goal.id, now);
        await _loadGoals();
        if (!wasCompleted && updated.isCompleted && mounted) {
          _xpOverlayKey.currentState?.showXPBurst(Gamification.xpPerDailyCompletion);
          showCelebrationOverlay(context);
        }
      } else {
        if (mounted) {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => GoalDetailScreen(goal: goal),
            ),
          );
          await _loadGoals();
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

  ({String text, Color color}) _getGreetingData() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return (
        text: 'GOOD MORNING!',
        color: const Color(0xFFFF9500), // Warm orange
      );
    }
    if (hour < 17) {
      return (
        text: 'GOOD AFTERNOON!',
        color: const Color(0xFF0891B2), // Darker cyan/teal
      );
    }
    return (
      text: 'GOOD EVENING!',
      color: const Color(0xFF8B5CF6), // Medium purple
    );
  }

  String _getSubtitle() {
    final activeGoals = _goals.where((g) => !g.isCompleted).toList();
    final dailyGoals = activeGoals.where((g) => g.goalType == GoalType.daily).toList();
    if (dailyGoals.isEmpty && activeGoals.isEmpty) {
      return 'All done for today!';
    }
    if (dailyGoals.isNotEmpty) {
      return 'You have ${dailyGoals.length} daily goal${dailyGoals.length == 1 ? '' : 's'} today';
    }
    return 'You have ${activeGoals.length} goal${activeGoals.length == 1 ? '' : 's'} in progress';
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
                    // Greeting header with cat mascot
                    _buildGreetingHeader(),
                    // XP banner
                    _buildXpBanner(level, totalXP, xpInLevel, levelProgress),
                    _buildFilterButtons(),
                    Expanded(
                      child: _filteredGoals.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              itemCount: _filteredGoals.length,
                              padding: const EdgeInsets.only(top: 8, bottom: 80),
                              itemBuilder: (context, index) {
                                final goal = _filteredGoals[index];
                                return _StaggeredGoalCard(
                                  index: index,
                                  hasAnimated: _hasAnimatedIn,
                                  onAnimationDone: () {
                                    if (index == _filteredGoals.length - 1) {
                                      _hasAnimatedIn = true;
                                    }
                                  },
                                  child: _buildGoalCard(goal, index),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'goals_list_fab',
          onPressed: () async {
            HapticFeedback.lightImpact();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddGoalScreen(),
              ),
            );
            await _loadGoals();
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.flag_rounded),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final greetingData = _getGreetingData();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated greeting with boxy font
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: Text(
                          greetingData.text,
                          style: GoogleFonts.pressStart2p(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: greetingData.color,
                            height: 1.4,
                            wordSpacing: -10,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  _getSubtitle(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/cat.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBannerColor() {
    final hour = DateTime.now().hour;
    if (hour < 12) return const Color(0xFFF09070);  // warm coral — morning
    if (hour < 17) return const Color(0xFF5CB8E4);  // clear sky blue — afternoon
    return const Color(0xFFA78BFA);                  // soft violet — evening
  }

  Widget _buildXpBanner(int level, int totalXP, int xpInLevel, double levelProgress) {
    final bannerColor = _getBannerColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: bannerColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Level circle — color tiers by level
                  Builder(builder: (context) {
                    final Color ringColor;
                    if (level >= 100) {
                      ringColor = const Color(0xFFFF4500); // red — legendary
                    } else if (level >= 50) {
                      ringColor = const Color(0xFFE040FB); // pink — epic
                    } else if (level >= 25) {
                      ringColor = const Color(0xFFFFD700); // gold — veteran
                    } else if (level >= 10) {
                      ringColor = const Color(0xFF4FC3F7); // sky blue — seasoned
                    } else {
                      ringColor = Colors.white;            // white — starter
                    }
                    return Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: ringColor.withValues(alpha: 0.8),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ringColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    child: Center(
                      child: Text(
                        '$level',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                  }),
                  const SizedBox(width: 14),
                  // Level info + progress bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEVEL $level',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Progress bar
                        Stack(
                          children: [
                            // Track
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            // Fill
                            FractionallySizedBox(
                              widthFactor: levelProgress.clamp(0.02, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$xpInLevel / 100 XP to next level',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Bottom stats row: total XP + streak
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Total XP
                    const Icon(Icons.bolt, size: 18, color: Color(0xFFFFD700)),
                    const SizedBox(width: 4),
                    Text(
                      '$totalXP XP',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // Streak
                    StreakBadge(streak: _perfectDayStreak, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _perfectDayStreak == 1 ? 'day' : 'days',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildFilterButton('TODO', GoalFilter.all)),
          Expanded(child: _buildFilterButton('Daily', GoalFilter.daily)),
          Expanded(child: _buildFilterButton('Long-term', GoalFilter.longTerm)),
          Expanded(child: _buildFilterButton('Finished', GoalFilter.completed)),
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
            HapticFeedback.lightImpact();
            setState(() {
              _filter = filter;
              _cachedFilteredGoals = null;
              _hasAnimatedIn = false;
            });
          }
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
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
              fontSize: 13,
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
      GoalFilter.all => 'Empty...',
      GoalFilter.daily => 'Boring...',
      GoalFilter.longTerm => 'Disappointing...',
      GoalFilter.completed => 'NOT COOL!',
    };

    final hint = _filter == GoalFilter.completed
        ? 'nothing to see here ...'
        : 'tap the flag to start a new goal';

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: _BouncingWidget(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/cat.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal, int index) {
    final now = DateTime.now();
    final progress = goal.getProgress();
    final isCompleted = goal.isCompleted;
    final accentColor = AppColors.getGoalAccent(index);

    // Wrap daily goals in Dismissible for swipe gestures
    Widget card = _PressableCard(
      onTap: () async {
        HapticFeedback.lightImpact();
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailScreen(goal: goal),
          ),
        );
        await _loadGoals();
        if (result != null && result['celebrate'] == true && mounted) {
          final xp = result['xp'] as int? ?? 20;
          _xpOverlayKey.currentState?.showXPBurst(xp);
          showCelebrationOverlay(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored left accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
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
                                    if (isCompleted) ...[
                                      const SizedBox(width: 8),
                                      const CrownBadge(size: 26),
                                    ] else ...[
                                      _buildGoalTypeBadge(goal),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildSubtitle(goal, now),
                              ],
                            ),
                          ),
                          // Circular mini-progress on the right
                          if (goal.goalType != GoalType.daily) ...[
                            const SizedBox(width: 8),
                            _buildMiniProgress(progress, isCompleted),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress label
                      Text(
                        ProgressFormatter.getDetailedProgressLabel(goal, now: now),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      // Full-width complete button for daily goals
                      if (!isCompleted && goal.goalType == GoalType.daily) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: AppColors.xpGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => _logProgress(goal),
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 20,
                                      color: AppColors.xpGreen,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Complete Today',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.xpGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Wrap in Dismissible for swipe gestures
    return Dismissible(
      key: ValueKey(goal.id),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.xpGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.check_circle, color: Colors.white, size: 32),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right -> complete daily goal
          if (goal.goalType == GoalType.daily && !isCompleted) {
            HapticFeedback.mediumImpact();
            await _logProgress(goal);
          }
          return false; // Don't actually dismiss
        } else {
          // Swipe left -> delete
          HapticFeedback.mediumImpact();
          await _deleteGoal(goal);
          return false;
        }
      },
      child: card,
    );
  }

  Widget _buildMiniProgress(double progress, bool isCompleted) {
    final color = isCompleted ? AppColors.xpGreen : Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '${(progress * 100).toInt()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Goal goal, bool isCompleted) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: isCompleted
          ? Theme.of(context).colorScheme.tertiary
          : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
      child: Icon(
        isCompleted ? Icons.check : _getGoalIcon(goal),
        color: isCompleted
            ? Colors.white
            : Theme.of(context).colorScheme.secondary,
        size: 18,
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
}

/// Staggered animation wrapper for goal cards
class _StaggeredGoalCard extends StatefulWidget {
  final int index;
  final Widget child;
  final bool hasAnimated;
  final VoidCallback onAnimationDone;

  const _StaggeredGoalCard({
    required this.index,
    required this.child,
    required this.hasAnimated,
    required this.onAnimationDone,
  });

  @override
  State<_StaggeredGoalCard> createState() => _StaggeredGoalCardState();
}

class _StaggeredGoalCardState extends State<_StaggeredGoalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.hasAnimated) {
      _controller.value = 1.0;
    } else {
      final delay = Duration(milliseconds: min(widget.index * 80, 400));
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward().then((_) => widget.onAnimationDone());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Card with press-down scale feedback
class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Gentle bounce animation for empty state
class _BouncingWidget extends StatefulWidget {
  final Widget child;

  const _BouncingWidget({required this.child});

  @override
  State<_BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<_BouncingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
