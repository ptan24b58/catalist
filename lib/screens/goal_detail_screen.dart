import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      HapticFeedback.heavyImpact();
      final wasCompleted = _goal.isCompleted;
      final updated = await goalRepository.logDailyCompletion(_goal.id, DateTime.now());
      await _loadGoal();

      // Only show XP burst and celebration when goal transitions to complete
      if (!wasCompleted && updated.isCompleted && mounted) {
        _xpOverlayKey.currentState?.showXPBurst(Gamification.xpPerDailyCompletion);
        showCelebrationOverlay(context);
      }
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

      if (_goal.goalType == GoalType.daily) {
        // Daily numeric: log each unit as individual completions
        for (var i = 0; i < value.toInt(); i++) {
          await goalRepository.logDailyCompletion(_goal.id, DateTime.now());
        }
      } else {
        final newValue = _goal.currentValue + value;
        await goalRepository.updateNumericProgress(_goal.id, newValue);
      }
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
    final accentColor = isCompleted ? AppColors.xpGreen : theme.colorScheme.primary;

    return XPBurstOverlay(
      key: _xpOverlayKey,
      child: Scaffold(
        backgroundColor: AppColors.surfaceTint,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceTint,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
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
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          child: Column(
            children: [
              _buildHeaderCard(context, accentColor, isCompleted),
              const SizedBox(height: 16),
              _buildProgressRingCard(context, progress, isCompleted, accentColor),
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
    );
  }

  // --- Card decoration ---

  static final _cardDecorationCached = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24)
  );

  BoxDecoration _cardDecoration(BuildContext context) => _cardDecorationCached;

  // --- 1. Header Card ---

  Widget _buildHeaderCard(BuildContext context, Color accentColor, bool isCompleted) {
    final theme = Theme.of(context);
    final createdDate = '${_goal.createdAt.month}/${_goal.createdAt.day}/${_goal.createdAt.year}';
    final isDaily = _goal.goalType == GoalType.daily;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDaily ? Icons.flag_rounded : Icons.rocket_launch_rounded,
                  size: 13,
                  color: accentColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isDaily ? 'Daily' : 'Long-term',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompleted) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: CrownIcon(size: 24),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  _goal.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Created date
          Text(
            'Created $createdDate',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Progress Ring Card ---

  Widget _buildProgressRingCard(BuildContext context, double progress, bool isCompleted, Color accentColor) {
    final theme = Theme.of(context);
    final trackColor = theme.colorScheme.surfaceContainerHighest;
    final isDaily = _goal.goalType == GoalType.daily;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _GradientCircularProgressPainter(
                      progress: progress,
                      trackColor: trackColor,
                      gradientColors: isCompleted
                          ? [AppColors.xpGreen, AppColors.xpGreen]
                          : [theme.colorScheme.primary, theme.colorScheme.primary],
                      strokeWidth: 10,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDaily ? Icons.flag_rounded : Icons.rocket_launch_rounded,
                      size: 20,
                      color: isCompleted
                          ? AppColors.xpGreen
                          : accentColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? AppColors.xpGreen : accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getStatusText(isCompleted),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? AppColors.xpGreen
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getProgressDescription(),
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- Status / description helpers ---

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

  static const _dailyCongrats = [
    'Great job today! Keep it up!',
    'Nailed it! Your cat is proud!',
    'Another day conquered!',
    'You\'re on fire! Keep going!',
  ];
  static const _longTermCongrats = [
    'You achieved your goal! Amazing work!',
    'Goal conquered! Time to celebrate!',
    'Incredible effort - you made it happen!',
    'Mission accomplished! What\'s next?',
  ];

  String _getProgressDescription() {
    if (_goal.isCompleted) {
      final msgs = _goal.goalType == GoalType.daily ? _dailyCongrats : _longTermCongrats;
      return msgs[_goal.title.length % msgs.length];
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

  // --- 3. Progress Controls ---

  Widget _buildProgressControls(BuildContext context) {
    return switch (_goal.progressType) {
      ProgressType.completion => _buildCompletionControls(context),
      ProgressType.percentage => _buildPercentageControls(context),
      ProgressType.milestones => _buildMilestoneControls(context),
      ProgressType.numeric => _buildNumericControls(context),
    };
  }

  /// Reusable "Completed" indicator widget
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

  // -- Completion Controls --

  Widget _buildCompletionControls(BuildContext context) {
    if (_goal.isCompleted) {
      return _buildCompletedIndicator(context);
    }

    final isDaily = _goal.goalType == GoalType.daily;

    return Container(
      decoration: _cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDaily ? _logDailyCompletion : _completeLongTermGoal,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.xpGreen],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    isDaily ? 'Mark Complete Today' : 'Mark as Complete',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Percentage Controls --

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
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 6,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
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
          const SizedBox(height: 16),
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

  // -- Milestone Controls --

  Widget _buildMilestoneControls(BuildContext context) {
    final theme = Theme.of(context);
    final completed = _goal.completedMilestones;
    final total = _goal.milestones.length;
    final milestoneProgress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress bar
          Row(
            children: [
              Text(
                'Milestones',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mini progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: milestoneProgress,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.xpGreen),
            ),
          ),
          const SizedBox(height: 20),
          // Timeline milestones
          ..._goal.milestones.asMap().entries.map((entry) {
            final milestone = entry.value;
            final index = entry.key;
            final isLast = index == _goal.milestones.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline dot + line
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: milestone.completed
                                ? AppColors.xpGreen
                                : theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: milestone.completed
                                  ? AppColors.xpGreen
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: milestone.completed
                              ? const Icon(Icons.check, size: 8, color: Colors.white)
                              : null,
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: milestone.completed
                                  ? AppColors.xpGreen.withValues(alpha: 0.4)
                                  : theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Milestone card
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _toggleMilestone(milestone),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: milestone.completed
                                  ? AppColors.xpGreen.withValues(alpha: 0.08)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    milestone.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      decoration: milestone.completed
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: milestone.completed
                                          ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (milestone.completed)
                                  const Icon(Icons.check_circle, color: AppColors.xpGreen, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -- Numeric Controls --

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
          TextField(
            controller: _progressController,
            decoration: InputDecoration(
              hintText: 'Enter amount',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              suffixText: unit.isNotEmpty ? unit : null,
              suffixStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _addNumericProgress(),
          ),
          const SizedBox(height: 12),
          // Quick-add buttons
          Row(
            children: [
              _buildQuickAddButton(context, 1),
              const SizedBox(width: 8),
              _buildQuickAddButton(context, 5),
              const SizedBox(width: 8),
              _buildQuickAddButton(context, 10),
              const Spacer(),
              Material(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  onPressed: _isNumericInputValid ? _addNumericProgress : null,
                  icon: const Icon(Icons.add, color: Colors.white, size: 24)
                ),
              ),
            ],
          ),
          if (_goal.goalType == GoalType.daily) ...[
            const SizedBox(height: 16),
            _buildDailyProgressBar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(BuildContext context, int value) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _progressController.text = value.toString();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '+$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    final todayProgress = _goal.getProgressToday(DateTime.now());
    final target = _goal.dailyTarget;
    final fraction = target > 0 ? (todayProgress / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Today',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              '${todayProgress.toInt()}/$target',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  // --- 4. Streak Card ---

  Widget _buildStreakCard() {
    return StreakCard(
      currentStreak: _goal.currentStreak,
      bestStreak: _goal.longestStreak,
    );
  }

  // --- 5. Deadline Card ---

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

/// Custom painter for gradient circular progress indicator
class _GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final List<Color> gradientColors;
  final double strokeWidth;

  _GradientCircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.gradientColors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Draw gradient arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi / 2 + 2 * pi * progress,
      colors: gradientColors,
    );
    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor;
  }
}
