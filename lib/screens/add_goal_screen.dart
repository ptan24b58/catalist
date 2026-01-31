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

  GoalType _goalType = GoalType.daily;
  ProgressType? _progressType;
  DateTime? _deadline;
  int _dailyTarget = 1;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _targetController.addListener(() => setState(() {}));
    _milestoneController.addListener(() => setState(() {}));
  }

  bool get _canAddMilestone {
    final text = _milestoneController.text.trim();
    if (text.isEmpty) return false;
    final sanitized = Validation.sanitizeMilestoneTitle(text);
    if (sanitized == null) return false;
    if (_milestoneInputs.length >= AppConstants.maxMilestones) return false;
    return true;
  }

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

  bool get _isStep0Valid => _titleController.text.trim().isNotEmpty;

  bool get _isStep1Valid => true; // _goalType defaults to daily

  bool get _isStep2Valid => _progressType != null;

  bool get _isStep3Valid {
    if (_progressType == ProgressType.milestones) {
      return _milestoneInputs.isNotEmpty;
    }
    if (_progressType == ProgressType.numeric && _goalType == GoalType.longTerm) {
      final target = double.tryParse(_targetController.text);
      return target != null && target > 0;
    }
    return true; // For other cases (daily numeric, percentage, completion)
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _isStep0Valid;
      case 1:
        return _isStep1Valid;
      case 2:
        return _isStep2Valid;
      case 3:
        return _isStep3Valid;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (!_canProceed || _currentStep >= 3) return;
    setState(() {
      _currentStep++;
      if (_currentStep == 2 &&
          _progressType == null &&
          _availableProgressTypes.isNotEmpty) {
        _progressType = _availableProgressTypes.first;
      }
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  bool _showCalendar = false;

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
        goalType: _goalType,
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Goal',
          style: theme.appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildCurrentStep(context),
              ),
            ),
            _buildNavigationButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Title(context);
      case 1:
        return _buildStep2GoalType(context);
      case 2:
        return _buildStep3ProgressType(context);
      case 3:
        return _buildStep4Details(context);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1Title(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What adventure are you starting?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 20),
        _wrapCard(
          context,
          child: TextField(
            controller: _titleController,
            autofocus: true,
            style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Drink more water? Read a book? Dream big!',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canProceed) _nextStep();
            },
          ),
        ),
      ],
    );
  }

  // Cached decoration to avoid recreation on every build
  static final _cardBoxDecoration = BoxDecoration(
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

  Widget _wrapCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBoxDecoration,
      child: child,
    );
  }

  Widget _buildStep2GoalType(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How often?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 20),
        _buildGoalTypeCard(
          context,
          title: 'Daily',
          subtitle: 'Do it every day',
          icon: Icons.repeat,
          isSelected: _goalType == GoalType.daily,
          onTap: () => setState(() {
            _goalType = GoalType.daily;
            _progressType = null;
          }),
        ),
        const SizedBox(height: 8),
        _buildGoalTypeCard(
          context,
          title: 'Long-term',
          subtitle: 'One big achievement',
          icon: Icons.flag_outlined,
          isSelected: _goalType == GoalType.longTerm,
          onTap: () => setState(() {
            _goalType = GoalType.longTerm;
            _progressType = null;
          }),
        ),
      ],
    );
  }

  Widget _buildGoalTypeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: _cardBoxDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep3ProgressType(BuildContext context) {
    final theme = Theme.of(context);
    if (_availableProgressTypes.isEmpty) {
      return Center(
        child: Text(
          'Please select a goal type first',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tracking method?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 20),
        ..._availableProgressTypes.map((type) {
          final isSelected = _progressType == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildProgressTypeCard(context, type, isSelected),
          );
        }),
      ],
    );
  }

  Widget _buildProgressTypeCard(BuildContext context, ProgressType type, bool isSelected) {
    final theme = Theme.of(context);
    final config = _getProgressTypeConfig(context, type);
    return Container(
      decoration: _cardBoxDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _progressType = type),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected
                      ? config.color.withValues(alpha: 0.2)
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    config.icon,
                    size: 20,
                    color: isSelected ? config.color : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({IconData icon, String title, String subtitle, Color color}) _getProgressTypeConfig(BuildContext context, ProgressType type) {
    final theme = Theme.of(context);
    return switch (type) {
      ProgressType.completion => (
          icon: Icons.check_circle_outline,
          title: 'Simple Check',
          subtitle: 'Just mark it done',
          color: AppColors.xpGreen,
        ),
      ProgressType.percentage => (
          icon: Icons.pie_chart_outline,
          title: 'Percentage',
          subtitle: 'Track 0-100% progress',
          color: theme.colorScheme.secondary,
        ),
      ProgressType.milestones => (
          icon: Icons.checklist,
          title: 'Milestones',
          subtitle: 'Complete step by step',
          color: theme.colorScheme.tertiary,
        ),
      ProgressType.numeric => (
          icon: Icons.trending_up,
          title: 'Numeric',
          subtitle: 'Track specific amounts',
          color: theme.colorScheme.primary,
        ),
    };
  }

  Widget _buildStep4Details(BuildContext context) {
    if (_progressType == ProgressType.milestones) {
      return _buildMilestonesStep(context);
    }
    if (_progressType == ProgressType.numeric) {
      return _buildNumericStep(context);
    }
    if (_goalType == GoalType.longTerm && _progressType != ProgressType.milestones) {
      return _buildDeadlineStep(context);
    }
    return _buildReviewStep(context);
  }

  Widget _buildMilestonesStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add milestones',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Break your goal into smaller steps',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
        _wrapCard(
          context,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _milestoneController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Complete chapter 1',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: (_) => _addMilestone(),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  onPressed: _canAddMilestone ? _addMilestone : null,
                  icon: const Icon(Icons.add, color: Colors.white)
                ),
              ),
            ],
          ),
        ),
        if (_milestoneInputs.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._milestoneInputs.asMap().entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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

  Widget _buildNumericStep(BuildContext context) {
    final theme = Theme.of(context);
    if (_goalType == GoalType.daily) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily target',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How many do you want to do each day?',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _wrapCard(
            context,
            child: Column(
              children: [
                Text(
                  '$_dailyTarget',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    thumbColor: theme.colorScheme.primary,
                  ),
                  child: Slider(
                    value: _dailyTarget.toDouble(),
                    min: 1,
                    max: AppConstants.defaultMaxTarget.toDouble(),
                    divisions: AppConstants.defaultMaxTarget - 1,
                    onChanged: (value) {
                      setState(() => _dailyTarget = value.toInt());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _wrapCard(
            context,
            child: TextField(
              controller: _unitController,
              decoration: InputDecoration(
                hintText: 'Unit (optional): e.g., glasses, reps, pages',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set your target',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'What\'s your goal number?',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _wrapCard(
                context,
                child: TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: '5000',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _wrapCard(
                context,
                child: TextField(
                  controller: _unitController,
                  decoration: InputDecoration(
                    hintText: 'Unit',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeadlineStep(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final deadlineLabel = _deadline != null
        ? '${months[_deadline!.month - 1]} ${_deadline!.day}, ${_deadline!.year}'
        : 'Pick a date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When\'s your deadline?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set a deadline to stay motivated (optional)',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
        // Date display card / toggle
        Container(
          decoration: _cardBoxDecoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _showCalendar = !_showCalendar),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _deadline != null
                          ? theme.colorScheme.primary.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: _deadline != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deadlineLabel,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _deadline != null
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          if (_deadline != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_deadline!.difference(now).inDays} days from now',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _showCalendar ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Inline calendar
        if (_showCalendar) ...[
          const SizedBox(height: 12),
          Container(
            decoration: _cardBoxDecoration,
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: theme.colorScheme.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: theme.colorScheme.onSurface,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ),
              child: CalendarDatePicker(
                initialDate: _deadline ?? now.add(const Duration(days: 30)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365 * 5)),
                onDateChanged: (picked) {
                  setState(() {
                    _deadline = picked;
                    _showCalendar = false;
                  });
                },
              ),
            ),
          ),
        ],
        if (_deadline != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _deadline = null),
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              label: Text(
                'Remove deadline',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final theme = Theme.of(context);
    final config = _progressType != null ? _getProgressTypeConfig(context, _progressType!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review your goal and let\'s start!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 20),
        _wrapCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildReviewItem(context, 'Type', _goalType == GoalType.daily ? 'Daily' : 'Long-term'),
              if (config != null)
                _buildReviewItem(context, 'Tracking', config.title),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: theme.colorScheme.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: _currentStep == 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: _canProceed ? (_currentStep == 3 ? _saveGoal : _nextStep) : null,
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
                child: Text(
                  _currentStep == 3 ? 'Create Goal' : 'Continue',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
