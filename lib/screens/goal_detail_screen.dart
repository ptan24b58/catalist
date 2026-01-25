import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../data/goal_repository.dart';
import '../widget_snapshot.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/logger.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late Goal _goal;
  final GoalRepository _repository = GoalRepository();
  final WidgetSnapshotService _snapshotService = WidgetSnapshotService();
  final _progressController = TextEditingController();
  double _percentageSliderValue = 0;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _percentageSliderValue = _goal.percentComplete;
    _loadGoal();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    try {
      final updated = await _repository.getGoalById(_goal.id);
      if (updated != null && mounted) {
        setState(() {
          _goal = updated;
          _percentageSliderValue = _goal.percentComplete;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load goal', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load goal details'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _logDailyCompletion() async {
    try {
      await _repository.logDailyCompletion(_goal.id, DateTime.now());
      await _snapshotService.generateSnapshot(isCelebration: true);
      await _loadGoal();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress logged!'),
            duration: Duration(seconds: 2),
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

  Future<void> _updatePercentage() async {
    try {
      await _repository.updatePercentage(_goal.id, _percentageSliderValue);
      await _snapshotService.generateSnapshot(
          isCelebration: _percentageSliderValue >= 100);
      await _loadGoal();

      if (mounted && _percentageSliderValue >= 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal completed!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update percentage', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _addNumericProgress() async {
    final value = double.tryParse(_progressController.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid number'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      final newValue = _goal.currentValue + value;
      await _repository.updateNumericProgress(_goal.id, newValue);
      await _snapshotService.generateSnapshot(
          isCelebration: _goal.targetValue != null && newValue >= _goal.targetValue!);
      _progressController.clear();
      await _loadGoal();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress updated!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update progress', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleMilestone(Milestone milestone) async {
    try {
      await _repository.toggleMilestone(_goal.id, milestone.id);
      final allComplete = _goal.milestones.every((m) => 
          m.id == milestone.id ? !milestone.completed : m.completed);
      await _snapshotService.generateSnapshot(isCelebration: allComplete);
      await _loadGoal();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle milestone', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _goal.getProgress();
    final isCompleted = _goal.isCompleted;

    return Scaffold(
      appBar: AppBar(
        title: Text(_goal.title),
        actions: [
          _buildGoalTypeBadge(),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Main Progress Card
          _buildMainProgressCard(progress, isCompleted),
          const SizedBox(height: 16),

          // Progress-specific controls
          _buildProgressControls(),

          // Stats Cards
          if (_goal.goalType == GoalType.daily) ...[
            const SizedBox(height: 16),
            _buildStreakCard(),
          ],

          if (_goal.goalType == GoalType.longTerm && _goal.deadline != null) ...[
            const SizedBox(height: 16),
            _buildDeadlineCard(),
          ],

          if (_goal.lastCompletedAt != null) ...[
            const SizedBox(height: 16),
            _buildLastActivityCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalTypeBadge() {
    final isDaily = _goal.goalType == GoalType.daily;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDaily
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isDaily ? 'Daily' : 'Long-term',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDaily
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }

  Widget _buildMainProgressCard(double progress, bool isCompleted) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProgressVisualization(progress, isCompleted),
            const SizedBox(height: 16),
            Text(
              _getStatusText(isCompleted),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isCompleted
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getProgressDescription(),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressVisualization(double progress, bool isCompleted) {
    // Circular progress for percentage and completion types
    if (_goal.progressType == ProgressType.percentage ||
        _goal.progressType == ProgressType.completion) {
      return SizedBox(
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
                strokeWidth: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Icon(
              isCompleted ? Icons.check : _getProgressIcon(),
              size: 48,
              color: isCompleted
                  ? Theme.of(context).colorScheme.tertiary
                  : Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    }

    // Linear progress for numeric and milestone types
    return Column(
      children: [
        Icon(
          isCompleted ? Icons.celebration : _getProgressIcon(),
          size: 64,
          color: isCompleted
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              isCompleted
                  ? Theme.of(context).colorScheme.tertiary
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getProgressIcon() {
    switch (_goal.progressType) {
      case ProgressType.completion:
        return Icons.check_circle_outline;
      case ProgressType.percentage:
        return Icons.pie_chart_outline;
      case ProgressType.milestones:
        return Icons.checklist;
      case ProgressType.numeric:
        return Icons.trending_up;
    }
  }

  String _getStatusText(bool isCompleted) {
    if (isCompleted) return 'Completed!';

    switch (_goal.progressType) {
      case ProgressType.completion:
        return _goal.goalType == GoalType.daily ? 'Not Done Today' : 'In Progress';
      case ProgressType.percentage:
        return '${_goal.percentComplete.toInt()}% Complete';
      case ProgressType.milestones:
        return '${_goal.completedMilestones}/${_goal.milestones.length} Milestones';
      case ProgressType.numeric:
        final unit = _goal.unit ?? '';
        return '${_goal.currentValue.toStringAsFixed(0)} / ${_goal.targetValue?.toStringAsFixed(0) ?? '?'} $unit';
    }
  }

  String _getProgressDescription() {
    if (_goal.isCompleted) {
      return _goal.goalType == GoalType.daily
          ? 'Great job today! Keep it up!'
          : 'You achieved your goal!';
    }

    switch (_goal.progressType) {
      case ProgressType.completion:
        return _goal.goalType == GoalType.daily
            ? 'Tap the button below to mark as complete'
            : 'Mark this goal as complete when you\'re done';
      case ProgressType.percentage:
        return 'Slide to update your progress';
      case ProgressType.milestones:
        final remaining = _goal.milestones.length - _goal.completedMilestones;
        return '$remaining milestone${remaining == 1 ? '' : 's'} remaining';
      case ProgressType.numeric:
        final remaining = (_goal.targetValue ?? 0) - _goal.currentValue;
        return '${remaining.toStringAsFixed(0)} ${_goal.unit ?? ''} to go';
    }
  }

  Widget _buildProgressControls() {
    switch (_goal.progressType) {
      case ProgressType.completion:
        return _buildCompletionControls();
      case ProgressType.percentage:
        return _buildPercentageControls();
      case ProgressType.milestones:
        return _buildMilestoneControls();
      case ProgressType.numeric:
        return _buildNumericControls();
    }
  }

  Widget _buildCompletionControls() {
    if (_goal.isCompleted) return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: _goal.goalType == GoalType.daily
          ? _logDailyCompletion
          : () async {
              await _repository.markLongTermComplete(_goal.id);
              await _snapshotService.generateSnapshot(isCelebration: true);
              await _loadGoal();
            },
      icon: const Icon(Icons.check),
      label: Text(_goal.goalType == GoalType.daily
          ? 'Mark Complete Today'
          : 'Mark as Complete'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildPercentageControls() {
    if (_goal.isCompleted) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Progress',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('0%'),
                Expanded(
                  child: Slider(
                    value: _percentageSliderValue,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_percentageSliderValue.toInt()}%',
                    onChanged: (value) {
                      setState(() => _percentageSliderValue = value);
                    },
                  ),
                ),
                const Text('100%'),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_percentageSliderValue.toInt()}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _percentageSliderValue != _goal.percentComplete
                  ? _updatePercentage
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Save Progress'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestones',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _goal.milestones.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final milestone = _goal.milestones[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: milestone.completed,
                    onChanged: (_) => _toggleMilestone(milestone),
                    activeColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  title: Text(
                    milestone.title,
                    style: TextStyle(
                      decoration: milestone.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: milestone.completed
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)
                          : null,
                    ),
                  ),
                  subtitle: milestone.completedAt != null
                      ? Text(
                          'Completed ${app_date_utils.DateUtils.formatDisplayDate(milestone.completedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        )
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericControls() {
    if (_goal.isCompleted) return const SizedBox.shrink();

    final unit = _goal.unit ?? '';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Progress',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
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
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.add),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onSubmitted: (_) => _addNumericProgress(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addNumericProgress,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_goal.goalType == GoalType.daily) ...[
              const SizedBox(height: 12),
              Text(
                'Daily progress: ${_goal.getProgressToday(DateTime.now()).toInt()}/${_goal.dailyTarget}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: ListTile(
              leading: Icon(
                Icons.local_fire_department,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Current Streak'),
              trailing: Text(
                '${_goal.currentStreak} days',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: ListTile(
              leading: Icon(
                Icons.emoji_events,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: const Text('Best'),
              trailing: Text(
                '${_goal.longestStreak} days',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineCard() {
    final daysRemaining = _goal.getDaysRemaining(DateTime.now());
    final isOverdue = _goal.isOverdue(DateTime.now());

    return Card(
      color: isOverdue
          ? Theme.of(context).colorScheme.errorContainer
          : null,
      child: ListTile(
        leading: Icon(
          isOverdue ? Icons.warning : Icons.calendar_today,
          color: isOverdue
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.secondary,
        ),
        title: Text(isOverdue ? 'Overdue!' : 'Deadline'),
        subtitle: Text(
          '${_goal.deadline!.month}/${_goal.deadline!.day}/${_goal.deadline!.year}',
        ),
        trailing: Text(
          isOverdue
              ? '${(-daysRemaining!)} days ago'
              : daysRemaining == 0
                  ? 'Today!'
                  : '$daysRemaining days left',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isOverdue
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLastActivityCard() {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.access_time,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: const Text('Last Activity'),
        trailing: Text(
          app_date_utils.DateUtils.formatDisplayDate(_goal.lastCompletedAt!),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
