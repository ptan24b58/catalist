import 'package:flutter/material.dart';
import '../domain/goal.dart';
import '../services/service_locator.dart';
import '../utils/constants.dart';
import '../utils/id_generator.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';
import '../utils/app_colors.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  int _currentStep = 0;
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  final _milestoneController = TextEditingController();
  final List<String> _milestoneInputs = [];

  GoalType? _goalType;
  ProgressType? _progressType;
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
    }
    if (_goalType == GoalType.longTerm) {
      return [ProgressType.percentage, ProgressType.milestones, ProgressType.numeric];
    }
    return [];
  }

  void _nextStep() {
    if (_currentStep == 0 && _titleController.text.trim().isEmpty) {
      return;
    }
    if (_currentStep == 1 && _goalType == null) {
      return;
    }
    if (_currentStep == 2 && _progressType == null) {
      return;
    }
    
    setState(() {
      if (_currentStep < 3) {
        _currentStep++;
        // Auto-select first progress type when goal type changes
        if (_currentStep == 2 && 
            _goalType != null && 
            _progressType == null && 
            _availableProgressTypes.isNotEmpty) {
          _progressType = _availableProgressTypes.first;
        }
      }
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
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
    if (text.isEmpty) return;
    
    // Validate and sanitize milestone title
    final sanitized = Validation.sanitizeMilestoneTitle(text);
    if (sanitized == null) {
      return;
    }
    
    if (_milestoneInputs.length >= AppConstants.maxMilestones) {
      return;
    }
    
    setState(() {
      _milestoneInputs.add(sanitized);
      _milestoneController.clear();
    });
  }

  void _removeMilestone(int index) {
    setState(() {
      _milestoneInputs.removeAt(index);
    });
  }

  Future<void> _saveGoal() async {
    if (_titleController.text.trim().isEmpty) {
      return;
    }

    if (_progressType == ProgressType.milestones && _milestoneInputs.isEmpty) {
      return;
    }

    if (_progressType == ProgressType.numeric && _goalType == GoalType.longTerm) {
      final target = double.tryParse(_targetController.text);
      if (target == null || target <= 0) {
        return;
      }
    }

    try {
      final sanitizedTitle = Validation.sanitizeTitle(_titleController.text);

      final milestones = _milestoneInputs
          .map((title) {
            final sanitized = Validation.sanitizeMilestoneTitle(title);
            return sanitized != null
                ? Milestone(
                    id: IdGenerator.generate(),
                    title: sanitized,
                  )
                : null;
          })
          .whereType<Milestone>()
          .toList();

      double? targetValue;
      if (_progressType == ProgressType.numeric) {
        if (_goalType == GoalType.daily) {
          targetValue = _dailyTarget.toDouble();
        } else {
          targetValue = double.tryParse(_targetController.text);
        }
      }

      final goal = Goal(
        id: IdGenerator.generate(),
        title: sanitizedTitle,
        goalType: _goalType!,
        progressType: _progressType!,
        targetValue: targetValue,
        unit: _unitController.text.trim().isEmpty
            ? null
            : _unitController.text.trim(),
        milestones: milestones,
        deadline: _goalType == GoalType.longTerm ? _deadline : null,
        createdAt: DateTime.now(),
      );

      await goalRepository.saveGoal(goal);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save goal', e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.catCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStep(),
              ),
            ),
            
            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.catOrange : AppColors.catOrangeLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Title();
      case 1:
        return _buildStep2GoalType();
      case 2:
        return _buildStep3ProgressType();
      case 3:
        return _buildStep4Details();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1Title() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What do you want to achieve?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Give your goal a name',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _titleController,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: r'e.g., Learn Spanish, Run 5K, Save $5000',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.catOrangeLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.catOrangeLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.catOrange, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          onSubmitted: (_) => _nextStep(),
        ),
      ],
    );
  }

  Widget _buildStep2GoalType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How often?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how you want to track this goal',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _buildGoalTypeCard(
          title: 'Daily',
          subtitle: 'Do it every day',
          icon: Icons.today,
          color: AppColors.catOrange,
          isSelected: _goalType == GoalType.daily,
          onTap: () => setState(() {
            _goalType = GoalType.daily;
            _progressType = null;
          }),
        ),
        const SizedBox(height: 12),
        _buildGoalTypeCard(
          title: 'Long-term',
          subtitle: 'One big achievement',
          icon: Icons.flag,
          color: AppColors.catBlue,
          isSelected: _goalType == GoalType.longTerm,
          onTap: () => setState(() {
            _goalType = GoalType.longTerm;
            _progressType = null;
          }),
        ),
      ],
    );
  }

  Widget _buildGoalTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.catOrangeLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3ProgressType() {
    if (_availableProgressTypes.isEmpty) {
      return const Center(
        child: Text('Please select a goal type first'),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How to track?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how you\'ll measure your progress',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        ..._availableProgressTypes.map((type) {
          final isSelected = _progressType == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildProgressTypeCard(type, isSelected),
          );
        }),
      ],
    );
  }

  Widget _buildProgressTypeCard(ProgressType type, bool isSelected) {
    final config = _getProgressTypeConfig(type);
    return InkWell(
      onTap: () => setState(() => _progressType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? config['color'].withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? config['color'] : AppColors.catOrangeLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              config['icon'],
              size: 24,
              color: isSelected ? config['color'] : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config['subtitle'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: config['color'], size: 24),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getProgressTypeConfig(ProgressType type) {
    return switch (type) {
      ProgressType.completion => {
          'icon': Icons.check_circle_outline,
          'title': 'Simple Check',
          'subtitle': 'Just mark it done',
          'color': AppColors.emotionHappy,
        },
      ProgressType.percentage => {
          'icon': Icons.pie_chart_outline,
          'title': 'Percentage',
          'subtitle': 'Track 0-100% progress',
          'color': AppColors.catBlue,
        },
      ProgressType.milestones => {
          'icon': Icons.checklist,
          'title': 'Milestones',
          'subtitle': 'Complete step by step',
          'color': AppColors.catGold,
        },
      ProgressType.numeric => {
          'icon': Icons.trending_up,
          'title': 'Numbers',
          'subtitle': 'Track specific amounts',
          'color': AppColors.catOrange,
        },
    };
  }

  Widget _buildStep4Details() {
    if (_progressType == ProgressType.milestones) {
      return _buildMilestonesStep();
    }
    if (_progressType == ProgressType.numeric) {
      return _buildNumericStep();
    }
    if (_goalType == GoalType.longTerm && _progressType != ProgressType.milestones) {
      return _buildDeadlineStep();
    }
    return _buildReviewStep();
  }

  Widget _buildMilestonesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add milestones',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Break your goal into smaller steps',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _milestoneController,
                decoration: InputDecoration(
                  hintText: 'e.g., Complete chapter 1',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.catOrangeLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.catOrangeLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.catOrange, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onSubmitted: (_) => _addMilestone(),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _addMilestone,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.catOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_milestoneInputs.isNotEmpty) ...[
          ..._milestoneInputs.asMap().entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.catOrangeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.catOrange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.value)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeMilestone(entry.key),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildNumericStep() {
    if (_goalType == GoalType.daily) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Daily target',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How many do you want to do each day?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.catOrangeLight),
            ),
            child: Column(
              children: [
                Text(
                  '$_dailyTarget',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.catOrange,
                  ),
                ),
                Slider(
                  value: _dailyTarget.toDouble(),
                  min: 1,
                  max: AppConstants.defaultMaxTarget.toDouble(),
                  divisions: AppConstants.defaultMaxTarget - 1,
                  onChanged: (value) {
                    setState(() => _dailyTarget = value.toInt());
                  },
                  activeColor: AppColors.catOrange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _unitController,
            decoration: InputDecoration(
              hintText: 'Unit (optional): e.g., glasses, reps, pages',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.catOrangeLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.catOrangeLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.catOrange, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set your target',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What\'s your goal number?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '5000',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.catOrangeLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.catOrangeLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.catOrange, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: InputDecoration(
                    hintText: 'Unit',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.catOrangeLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.catOrangeLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.catOrange, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildDeadlineStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When\'s your deadline?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set a deadline to stay motivated (optional)',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _selectDeadline,
          icon: const Icon(Icons.calendar_today, size: 20),
          label: Text(
            _deadline == null
                ? 'Pick a date'
                : '${_deadline!.month}/${_deadline!.day}/${_deadline!.year}',
            style: const TextStyle(fontSize: 16),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.catOrange,
            side: const BorderSide(color: AppColors.catOrange),
            padding: const EdgeInsets.all(16),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        if (_deadline != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _deadline = null),
            child: const Text('Remove deadline'),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ready to go',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review your goal and let\'s start',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.catOrangeLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildReviewItem('Type', _goalType == GoalType.daily ? 'Daily' : 'Long-term'),
              _buildReviewItem('Tracking', _getProgressTypeConfig(_progressType!)['title']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.catOrange, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.catOrange,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _currentStep == 3 ? _saveGoal : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _currentStep == 3 ? 'Create Goal' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
