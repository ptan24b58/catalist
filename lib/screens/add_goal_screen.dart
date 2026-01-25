import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../data/goal_repository.dart';
import '../widget_snapshot.dart';
import '../utils/validation.dart';
import '../utils/id_generator.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  final List<String> _milestoneInputs = [];
  final _milestoneController = TextEditingController();

  GoalType _goalType = GoalType.daily;
  ProgressType _progressType = ProgressType.completion;
  DateTime? _deadline;
  int _dailyTarget = 1;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _milestoneController.dispose();
    super.dispose();
  }

  List<ProgressType> get _availableProgressTypes {
    if (_goalType == GoalType.daily) {
      return [ProgressType.completion, ProgressType.numeric];
    } else {
      return [ProgressType.percentage, ProgressType.milestones, ProgressType.numeric];
    }
  }

  void _onGoalTypeChanged(GoalType? type) {
    if (type == null) return;
    setState(() {
      _goalType = type;
      // Reset progress type to first available option
      _progressType = _availableProgressTypes.first;
    });
  }

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _addMilestone() {
    final text = _milestoneController.text.trim();
    if (text.isNotEmpty && _milestoneInputs.length < AppConstants.maxMilestones) {
      setState(() {
        _milestoneInputs.add(text);
        _milestoneController.clear();
      });
    }
  }

  void _removeMilestone(int index) {
    setState(() {
      _milestoneInputs.removeAt(index);
    });
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for specific progress types
    if (_progressType == ProgressType.milestones && _milestoneInputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one milestone'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_progressType == ProgressType.numeric) {
      final target = double.tryParse(_targetController.text);
      if (target == null || target <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a valid target value'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    try {
      final repository = GoalRepository();
      final snapshotService = WidgetSnapshotService();

      final sanitizedTitle = Validation.sanitizeTitle(_titleController.text);

      // Build milestones list
      final milestones = _milestoneInputs
          .map((title) => Milestone(
                id: IdGenerator.generate(),
                title: title,
              ))
          .toList();

      // Parse numeric target
      double? targetValue;
      if (_progressType == ProgressType.numeric) {
        targetValue = double.tryParse(_targetController.text);
        if (_goalType == GoalType.daily) {
          targetValue = _dailyTarget.toDouble();
        }
      }

      final goal = Goal(
        id: IdGenerator.generate(),
        title: sanitizedTitle,
        goalType: _goalType,
        progressType: _progressType,
        targetValue: targetValue,
        unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
        milestones: milestones,
        deadline: _goalType == GoalType.longTerm ? _deadline : null,
        createdAt: DateTime.now(),
      );

      await repository.saveGoal(goal);
      await snapshotService.generateSnapshot();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save goal', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save goal: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Goal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Goal Title',
                hintText: 'e.g., Learn Spanish, Save for vacation',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              validator: Validation.validateTitle,
              autofocus: true,
            ),
            const SizedBox(height: 24),

            // Goal Type Selection
            _buildSectionTitle('Goal Type'),
            const SizedBox(height: 8),
            _buildGoalTypeSelector(),
            const SizedBox(height: 24),

            // Progress Type Selection
            _buildSectionTitle('How to Track Progress'),
            const SizedBox(height: 8),
            _buildProgressTypeSelector(),
            const SizedBox(height: 24),

            // Conditional Fields based on progress type
            ..._buildConditionalFields(),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveGoal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text(
                'Create Goal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildGoalTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeCard(
            title: 'Daily',
            subtitle: 'Recurring every day',
            icon: Icons.repeat,
            isSelected: _goalType == GoalType.daily,
            onTap: () => _onGoalTypeChanged(GoalType.daily),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTypeCard(
            title: 'Long-term',
            subtitle: 'One-time achievement',
            icon: Icons.flag,
            isSelected: _goalType == GoalType.longTerm,
            onTap: () => _onGoalTypeChanged(GoalType.longTerm),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableProgressTypes.map((type) {
        final isSelected = _progressType == type;
        return ChoiceChip(
          label: Text(_getProgressTypeLabel(type)),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _progressType = type);
            }
          },
          avatar: Icon(
            _getProgressTypeIcon(type),
            size: 18,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }

  String _getProgressTypeLabel(ProgressType type) {
    switch (type) {
      case ProgressType.completion:
        return 'Simple Check';
      case ProgressType.percentage:
        return 'Percentage';
      case ProgressType.milestones:
        return 'Milestones';
      case ProgressType.numeric:
        return 'Numeric Target';
    }
  }

  IconData _getProgressTypeIcon(ProgressType type) {
    switch (type) {
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

  List<Widget> _buildConditionalFields() {
    final widgets = <Widget>[];

    // Deadline for long-term goals
    if (_goalType == GoalType.longTerm) {
      widgets.addAll([
        _buildSectionTitle('Deadline (Optional)'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _selectDeadline,
          icon: const Icon(Icons.calendar_today),
          label: Text(
            _deadline == null
                ? 'Set Deadline'
                : '${_deadline!.month}/${_deadline!.day}/${_deadline!.year}',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            alignment: Alignment.centerLeft,
          ),
        ),
        if (_deadline != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _deadline = null),
            child: const Text('Remove deadline'),
          ),
        ],
        const SizedBox(height: 24),
      ]);
    }

    // Numeric target fields
    if (_progressType == ProgressType.numeric) {
      if (_goalType == GoalType.daily) {
        widgets.addAll([
          _buildSectionTitle('Daily Target'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _dailyTarget.toDouble(),
                  min: 1,
                  max: AppConstants.defaultMaxTarget.toDouble(),
                  divisions: AppConstants.defaultMaxTarget - 1,
                  label: _dailyTarget.toString(),
                  onChanged: (value) {
                    setState(() => _dailyTarget = value.toInt());
                  },
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_dailyTarget',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _unitController,
            decoration: const InputDecoration(
              labelText: 'Unit (Optional)',
              hintText: 'e.g., glasses, reps, pages',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.straighten),
            ),
          ),
          const SizedBox(height: 24),
        ]);
      } else {
        widgets.addAll([
          _buildSectionTitle('Target Value'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: 'Target',
                    hintText: 'e.g., 5000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Enter a number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: '\$, kg, km',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ]);
      }
    }

    // Milestones
    if (_progressType == ProgressType.milestones) {
      widgets.addAll([
        _buildSectionTitle('Milestones'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _milestoneController,
                decoration: const InputDecoration(
                  labelText: 'Add Milestone',
                  hintText: 'e.g., Complete chapter 1',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _addMilestone(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addMilestone,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_milestoneInputs.isNotEmpty) ...[
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _milestoneInputs.length,
            itemBuilder: (context, index) {
              return ListTile(
                key: ValueKey('milestone_$index'),
                leading: CircleAvatar(
                  radius: 14,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                title: Text(_milestoneInputs[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _removeMilestone(index),
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _milestoneInputs.removeAt(oldIndex);
                _milestoneInputs.insert(newIndex, item);
              });
            },
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Text(
              'No milestones added yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 24),
      ]);
    }

    return widgets;
  }
}
