import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../services/service_locator.dart';
import '../utils/logger.dart';
import '../utils/gamification.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_helper.dart';
import '../widgets/gamification/streak_badge.dart';
import '../widgets/gamification/crown_icon.dart';
import '../widgets/gamification/xp_burst.dart';
import '../widgets/celebration_overlay.dart';
import 'memory_capture_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late Goal _goal;
  final _progressController = TextEditingController();
  double _percentageSliderValue = 0;
  final GlobalKey<XPBurstOverlayState> _xpOverlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _percentageSliderValue = _goal.percentComplete;
    _progressController.addListener(() => setState(() {}));
    _loadGoal();
  }

  bool get _isNumericInputValid {
    if (_goal.progressType != ProgressType.numeric) return true;
    final value = double.tryParse(_progressController.text);
    return value != null && value > 0;
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    try {
      final updated = await goalRepository.getGoalById(_goal.id);
      if (updated != null && mounted) {
        setState(() {
          _goal = updated;
          _percentageSliderValue = _goal.percentComplete;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load goal', e, stackTrace);
    }
  }

  Future<void> _logDailyCompletion() async {
    try {
      await goalRepository.logDailyCompletion(_goal.id, DateTime.now());
      // Show XP burst
      _xpOverlayKey.currentState?.showXPBurst(Gamification.xpPerDailyCompletion);
      await _loadGoal();

      if (mounted) showCelebrationOverlay(context);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to log progress', e, stackTrace);
    }
  }

  Future<void> _updatePercentage() async {
    try {
      final wasCompleted = _goal.isCompleted;
      await goalRepository.updatePercentage(_goal.id, _percentageSliderValue);

      await _loadGoal();

      // Navigate to accomplishment capture for long-term goal completion
      if (mounted && _percentageSliderValue >= 100 && !wasCompleted) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryCaptureScreen(goal: _goal),
          ),
        );
        
        if (result != null && result['celebrate'] == true && mounted) {
          Navigator.of(context).pop({
            'celebrate': true,
            'xp': result['xp'] ?? 20,
          });
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update percentage', e, stackTrace);
    }
  }

  Future<void> _addNumericProgress() async {
    final value = double.tryParse(_progressController.text);
    if (value == null || value <= 0) {
      return;
    }

    try {
      final wasCompleted = _goal.isCompleted;
      final newValue = _goal.currentValue + value;
      await goalRepository.updateNumericProgress(_goal.id, newValue);
      _progressController.clear();

      await _loadGoal();

      // Navigate to accomplishment capture for long-term goal completion
      if (mounted && _goal.isCompleted && !wasCompleted && _goal.goalType == GoalType.longTerm) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryCaptureScreen(goal: _goal),
          ),
        );
        
        if (result != null && result['celebrate'] == true && mounted) {
          Navigator.of(context).pop({
            'celebrate': true,
            'xp': result['xp'] ?? 20,
          });
        }
      } else if (mounted && _goal.isCompleted && !wasCompleted) {
        // Daily goal - just show celebration
        showCelebrationOverlay(context);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update progress', e, stackTrace);
    }
  }

  Future<void> _toggleMilestone(Milestone milestone) async {
    try {
      final wasGoalCompleted = _goal.isCompleted;
      await goalRepository.toggleMilestone(_goal.id, milestone.id);

      await _loadGoal();

      // Navigate to accomplishment capture for long-term goal completion
      if (mounted && _goal.isCompleted && !wasGoalCompleted) {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryCaptureScreen(goal: _goal),
          ),
        );
        
        if (result != null && result['celebrate'] == true && mounted) {
          Navigator.of(context).pop({
            'celebrate': true,
            'xp': result['xp'] ?? 20,
          });
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle milestone', e, stackTrace);
    }
  }

  Future<void> _deleteGoal() async {
    final confirmed = await DialogHelper.showDeleteGoalConfirmation(
      context,
      goalTitle: _goal.title,
    );
    if (confirmed) {
      try {
        await goalRepository.deleteGoal(_goal.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e, stackTrace) {
        AppLogger.error('Failed to delete goal', e, stackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _goal.getProgress();
    final isCompleted = _goal.isCompleted;
    final theme = Theme.of(context);
    final headerColor = isCompleted
        ? AppColors.xpGreen
        : theme.colorScheme.primary;

    return XPBurstOverlay(
      key: _xpOverlayKey,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: headerColor,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          const SizedBox(width: 12),
                          const Text('Delete Goal'),
                        ],
                      ),
                      onTap: () async {
                        await Future.delayed(const Duration(milliseconds: 100));
                        _deleteGoal();
                      },
                    ),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompleted) ...[
                      const CrownIcon(size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        _goal.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                background: Container(color: headerColor),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  children: [
                    _buildMainProgressCard(context, progress, isCompleted),
                    const SizedBox(height: 16),
                    _buildProgressControls(context),
                    if (_goal.goalType == GoalType.daily) ...[
                      const SizedBox(height: 16),
                      _buildStreakCard(),
                    ],
                    if (_goal.goalType == GoalType.longTerm && _goal.deadline != null) ...[
                      const SizedBox(height: 16),
                      _buildDeadlineCard(context),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cached card decoration to avoid recreating on every build
  static final _cardDecorationCached = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  BoxDecoration _cardDecoration(BuildContext context) => _cardDecorationCached;

  /// Reusable "Completed" indicator widget - extracted to avoid duplication
  Widget _buildCompletedIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.xpGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.xpGreen, size: 24),
            SizedBox(width: 8),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.xpGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMainProgressCard(BuildContext context, double progress, bool isCompleted) {
    final theme = Theme.of(context);
    final progressColor = isCompleted ? AppColors.xpGreen : theme.colorScheme.primary;
    final trackColor = theme.colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    Text(
                      _getStatusText(isCompleted),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getProgressDescription(),
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getStatusText(bool isCompleted) {
    if (isCompleted) return 'Completed!';
    return switch (_goal.progressType) {
      ProgressType.completion => _goal.goalType == GoalType.daily
          ? 'Not Done Today'
          : 'In Progress',
      ProgressType.percentage => '${_goal.percentComplete.toInt()}% Complete',
      ProgressType.milestones =>
        '${_goal.completedMilestones}/${_goal.milestones.length} Milestones',
      ProgressType.numeric =>
        '${_goal.currentValue.toStringAsFixed(0)} / ${_goal.targetValue?.toStringAsFixed(0) ?? '?'} ${_goal.unit ?? ''}',
    };
  }

  String _getProgressDescription() {
    if (_goal.isCompleted) {
      return _goal.goalType == GoalType.daily
          ? 'Great job today! Keep it up!'
          : 'You achieved your goal! Amazing work!';
    }
    return switch (_goal.progressType) {
      ProgressType.completion => _goal.goalType == GoalType.daily
          ? 'Tap the button below to mark as complete'
          : "Mark this goal as complete when you're done",
      ProgressType.percentage => 'Slide to update your progress',
      ProgressType.milestones => () {
          final remaining = _goal.milestones.length - _goal.completedMilestones;
          return '$remaining milestone${remaining == 1 ? '' : 's'} remaining';
        }(),
      ProgressType.numeric =>
        '${((_goal.targetValue ?? 0) - _goal.currentValue).toStringAsFixed(0)} ${_goal.unit ?? ''} to go',
    };
  }

  Widget _buildProgressControls(BuildContext context) {
    return switch (_goal.progressType) {
      ProgressType.completion => _buildCompletionControls(context),
      ProgressType.percentage => _buildPercentageControls(context),
      ProgressType.milestones => _buildMilestoneControls(context),
      ProgressType.numeric => _buildNumericControls(context),
    };
  }

  Future<void> _completeLongTermGoal() async {
    // First mark the goal as complete
    await goalRepository.markLongTermComplete(_goal.id);
    await _loadGoal();
    
    if (!mounted) return;
    
    // Navigate to accomplishment capture screen
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryCaptureScreen(goal: _goal),
      ),
    );
    
    // If celebrate flag is set, pop back to goal list with the flag and XP
    if (result != null && result['celebrate'] == true) {
      if (mounted) {
        Navigator.of(context).pop({
          'celebrate': true,
          'xp': result['xp'] ?? 20,
        });
      }
    }
  }

  Widget _buildCompletionControls(BuildContext context) {
    if (_goal.isCompleted) {
      return _buildCompletedIndicator(context);
    }

    return ElevatedButton.icon(
      onPressed: _goal.goalType == GoalType.daily
          ? _logDailyCompletion
          : _completeLongTermGoal,
      icon: const Icon(Icons.check_circle, size: 24),
      label: Text(
        _goal.goalType == GoalType.daily
            ? 'Mark Complete Today'
            : 'Mark as Complete',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: AppColors.xpGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildPercentageControls(BuildContext context) {
    final theme = Theme.of(context);
    if (_goal.isCompleted) {
      return _buildCompletedIndicator(context);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          Text(
            '${_percentageSliderValue.toInt()}%',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              thumbColor: theme.colorScheme.primary,
            ),
            child: Slider(
              value: _percentageSliderValue,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_percentageSliderValue.toInt()}%',
              onChanged: (value) {
                setState(() => _percentageSliderValue = value);
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _percentageSliderValue != _goal.percentComplete
                  ? _updatePercentage
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Progress',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneControls(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Milestones',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ..._goal.milestones.asMap().entries.map((entry) {
            final milestone = entry.value;
            final index = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleMilestone(milestone),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: milestone.completed
                          ? AppColors.xpGreen.withValues(alpha: 0.08)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: milestone.completed
                              ? AppColors.xpGreen
                              : theme.colorScheme.primary.withValues(alpha: 0.2),
                          child: milestone.completed
                              ? const Icon(Icons.check, color: Colors.white, size: 22)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            milestone.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              decoration: milestone.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: milestone.completed
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNumericControls(BuildContext context) {
    final theme = Theme.of(context);
    if (_goal.isCompleted) {
      return _buildCompletedIndicator(context);
    }

    final unit = _goal.unit ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log Progress',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _progressController,
                  decoration: InputDecoration(
                    hintText: unit.isNotEmpty ? 'Add $unit (e.g., 10)' : 'e.g., 10',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _addNumericProgress(),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  onPressed: _isNumericInputValid ? _addNumericProgress : null,
                  icon: const Icon(Icons.add, color: Colors.white, size: 24),
                  style: IconButton.styleFrom(
                    disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                    disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          if (_goal.goalType == GoalType.daily) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Today: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '${_goal.getProgressToday(DateTime.now()).toInt()}/${_goal.dailyTarget}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return StreakCard(
      currentStreak: _goal.currentStreak,
      bestStreak: _goal.longestStreak,
    );
  }

  Widget _buildDeadlineCard(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysRemaining = _goal.getDaysRemaining(now);
    final isOverdue = _goal.isOverdue(now);
    final accentColor = isOverdue ? theme.colorScheme.error : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context).copyWith(
        color: isOverdue ? theme.colorScheme.error.withValues(alpha: 0.06) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: accentColor.withValues(alpha: 0.15),
            child: Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today,
              size: 24,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverdue ? 'Overdue' : 'Deadline',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_goal.deadline!.month}/${_goal.deadline!.day}/${_goal.deadline!.year}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            isOverdue
                ? '${(-daysRemaining!)} days ago'
                : daysRemaining == 0
                    ? 'Today!'
                    : '$daysRemaining days left',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

}

