import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../services/service_locator.dart';
import '../utils/logger.dart';
import '../utils/gamification.dart';
import '../utils/app_colors.dart';
import '../widgets/gamification/streak_badge.dart';
import '../widgets/gamification/crown_icon.dart';
import '../widgets/gamification/xp_burst.dart';
import '../widgets/celebration_overlay.dart';

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
      final oldPercent = _goal.percentComplete;
      await goalRepository.updatePercentage(_goal.id, _percentageSliderValue);

      // Show XP burst for progress
      if (_percentageSliderValue > oldPercent) {
        final xpEarned = ((_percentageSliderValue - oldPercent) / 10).round() * 2;
        if (xpEarned > 0) {
          _xpOverlayKey.currentState?.showXPBurst(xpEarned);
        }
      }

      await _loadGoal();

      if (mounted && _percentageSliderValue >= 100) {
        showCelebrationOverlay(context);
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
      final newValue = _goal.currentValue + value;
      await goalRepository.updateNumericProgress(_goal.id, newValue);
      _progressController.clear();

      // Show XP burst for progress
      final xpEarned = (value / 10).round().clamp(1, 10);
      _xpOverlayKey.currentState?.showXPBurst(xpEarned);

      await _loadGoal();

      if (mounted && _goal.isCompleted) showCelebrationOverlay(context);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update progress', e, stackTrace);
    }
  }

  Future<void> _toggleMilestone(Milestone milestone) async {
    try {
      final wasCompleted = milestone.completed;
      await goalRepository.toggleMilestone(_goal.id, milestone.id);

      // Show XP burst for completing a milestone
      if (!wasCompleted) {
        _xpOverlayKey.currentState?.showXPBurst(Gamification.xpPerMilestone);
      }

      await _loadGoal();

      if (mounted && _goal.isCompleted) showCelebrationOverlay(context);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle milestone', e, stackTrace);
    }
  }

  Future<void> _deleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "${_goal.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
    final cardColor = Gamification.getGoalCardColor(_goal);

    return XPBurstOverlay(
      key: _xpOverlayKey,
      child: Scaffold(
        backgroundColor: AppColors.catCream,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Gamified header
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  backgroundColor: isCompleted ? AppColors.emotionHappy : cardColor,
                  actions: [
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.delete, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Delete Goal'),
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
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.emotionHappy : cardColor,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Main progress card
                        _buildMainProgressCard(progress, isCompleted, cardColor),
                        const SizedBox(height: 20),

                        // Progress controls
                        _buildProgressControls(),

                        // Stats cards
                        if (_goal.goalType == GoalType.daily) ...[
                          const SizedBox(height: 20),
                          _buildStreakCard(),
                        ],

                        if (_goal.goalType == GoalType.longTerm && _goal.deadline != null) ...[
                          const SizedBox(height: 20),
                          _buildDeadlineCard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMainProgressCard(double progress, bool isCompleted, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                    backgroundColor: AppColors.catOrangeLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? AppColors.emotionHappy : AppColors.catOrange,
                    ),
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
                        color: isCompleted ? AppColors.emotionHappy : AppColors.catOrange,
                      ),
                    ),
                    Text(
                      _getStatusText(isCompleted),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
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

  Widget _buildProgressControls() {
    return switch (_goal.progressType) {
      ProgressType.completion => _buildCompletionControls(),
      ProgressType.percentage => _buildPercentageControls(),
      ProgressType.milestones => _buildMilestoneControls(),
      ProgressType.numeric => _buildNumericControls(),
    };
  }

  Widget _buildCompletionControls() {
    if (_goal.isCompleted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.emotionHappy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emotionHappy, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.emotionHappy,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.emotionHappy,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _goal.goalType == GoalType.daily
          ? _logDailyCompletion
          : () async {
              await goalRepository.markLongTermComplete(_goal.id);
              await _loadGoal();
              if (mounted) showCelebrationOverlay(context);
            },
      icon: const Icon(Icons.check_circle, size: 28),
      label: Text(
        _goal.goalType == GoalType.daily
            ? 'Mark Complete Today'
            : 'Mark as Complete',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        minimumSize: const Size(double.infinity, 64),
        backgroundColor: AppColors.emotionHappy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildPercentageControls() {
    if (_goal.isCompleted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.emotionHappy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emotionHappy, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.emotionHappy,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.emotionHappy,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${_percentageSliderValue.toInt()}%',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.catOrange,
            ),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _percentageSliderValue,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_percentageSliderValue.toInt()}%',
            onChanged: (value) {
              setState(() => _percentageSliderValue = value);
            },
            activeColor: AppColors.catOrange,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _percentageSliderValue != _goal.percentComplete
                ? _updatePercentage
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.catOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Milestones',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ..._goal.milestones.asMap().entries.map((entry) {
            final milestone = entry.value;
            final index = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _toggleMilestone(milestone),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: milestone.completed
                        ? AppColors.emotionHappy.withValues(alpha: 0.1)
                        : AppColors.catOrangeLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: milestone.completed
                          ? AppColors.emotionHappy
                          : AppColors.catOrangeLight,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: milestone.completed
                              ? AppColors.emotionHappy
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: milestone.completed
                                ? AppColors.emotionHappy
                                : AppColors.catOrange,
                            width: 2,
                          ),
                        ),
                        child: milestone.completed
                            ? const Icon(Icons.check, color: Colors.white)
                            : Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.catOrange,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          milestone.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: milestone.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: milestone.completed
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNumericControls() {
    if (_goal.isCompleted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.emotionHappy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.emotionHappy, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.emotionHappy,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.emotionHappy,
              ),
            ),
          ],
        ),
      );
    }

    final unit = _goal.unit ?? '';
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log Progress',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _progressController,
                  decoration: InputDecoration(
                    labelText: 'Add $unit',
                    hintText: 'e.g., 10',
                    filled: true,
                    fillColor: AppColors.catCream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _addNumericProgress(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isNumericInputValid ? _addNumericProgress : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.catOrangeLight,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.add, size: 28),
              ),
            ],
          ),
          if (_goal.goalType == GoalType.daily) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.catOrangeLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Today: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_goal.getProgressToday(now).toInt()}/${_goal.dailyTarget}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.catOrange,
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

  Widget _buildDeadlineCard() {
    final now = DateTime.now();
    final daysRemaining = _goal.getDaysRemaining(now);
    final isOverdue = _goal.isOverdue(now);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOverdue ? AppColors.error.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue ? AppColors.error : AppColors.catBlue,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.calendar_today,
            size: 40,
            color: isOverdue ? AppColors.error : AppColors.catBlue,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverdue ? 'Overdue!' : 'Deadline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isOverdue ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_goal.deadline!.month}/${_goal.deadline!.day}/${_goal.deadline!.year}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isOverdue ? AppColors.error : AppColors.catBlue,
            ),
          ),
        ],
      ),
    );
  }

}

