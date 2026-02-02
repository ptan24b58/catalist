import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../domain/event.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/id_generator.dart';

class AddEditEventScreen extends StatefulWidget {
  final CalendarEvent? existingEvent;
  final DateTime? initialDate;

  const AddEditEventScreen({
    super.key,
    this.existingEvent,
    this.initialDate,
  });

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _titleFocusNode = FocusNode();

  late DateTime _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  EventCategory _category = EventCategory.personal;
  ReminderOption _reminder = ReminderOption.none;
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get _isEditing => widget.existingEvent != null;
  bool get _isValid => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (_isEditing) {
      final e = widget.existingEvent!;
      _titleController.text = e.title;
      _notesController.text = e.notes ?? '';
      _date = e.date;
      _startTime = e.startTime;
      _endTime = e.endTime;
      _isAllDay = e.isAllDay;
      _category = e.category;
      _reminder = ReminderOption.values.firstWhere(
        (r) => r.minutes == e.reminderMinutesBefore,
        orElse: () => ReminderOption.none,
      );
    } else {
      _date = widget.initialDate ?? DateTime.now();
    }

    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  // ─── Date/time helpers ───

  String _formatDateCasually(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = dateOnly.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 0 && diff < 7) return DateFormat('EEEE').format(date);
    if (date.year == now.year) return DateFormat('MMM d').format(date);
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await _showDateSheet(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStartTime() async {
    HapticFeedback.selectionClick();
    final picked =
        await _showTimeSheet(context, _startTime ?? TimeOfDay.now(), 'Start time');
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    HapticFeedback.selectionClick();
    final picked = await _showTimeSheet(
        context, _endTime ?? _startTime ?? TimeOfDay.now(), 'End time');
    if (picked != null) setState(() => _endTime = picked);
  }

  // ─── Custom bottom-sheet pickers ───

  Future<TimeOfDay?> _showTimeSheet(
      BuildContext ctx, TimeOfDay initial, String title) {
    int selectedHour = initial.hourOfPeriod == 0 ? 12 : initial.hourOfPeriod;
    int selectedMinute = initial.minute;
    bool isAM = initial.period == DayPeriod.am;

    final hourController =
        FixedExtentScrollController(initialItem: selectedHour - 1);
    final minuteController =
        FixedExtentScrollController(initialItem: selectedMinute);
    final periodController =
        FixedExtentScrollController(initialItem: isAM ? 0 : 1);

    return showModalBottomSheet<TimeOfDay>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.access_time_rounded,
                            size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Scroll wheels
                SizedBox(
                  height: 180,
                  child: Stack(
                    children: [
                      // Selection highlight
                      Center(
                        child: Container(
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Hour wheel
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: hourController,
                              itemExtent: 44,
                              perspective: 0.003,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                HapticFeedback.selectionClick();
                                setSheetState(() => selectedHour = i + 1);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 12,
                                builder: (context, index) {
                                  final h = index + 1;
                                  final isSel = h == selectedHour;
                                  return Center(
                                    child: Text(
                                      '$h',
                                      style: TextStyle(
                                        fontSize: isSel ? 24 : 18,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isSel
                                            ? AppColors.primary
                                            : AppColors.textSecondary
                                                .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Colon
                          const Text(
                            ':',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          // Minute wheel
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: minuteController,
                              itemExtent: 44,
                              perspective: 0.003,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                HapticFeedback.selectionClick();
                                setSheetState(() => selectedMinute = i);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 60,
                                builder: (context, index) {
                                  final isSel = index == selectedMinute;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isSel ? 24 : 18,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isSel
                                            ? AppColors.primary
                                            : AppColors.textSecondary
                                                .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // AM/PM wheel
                          SizedBox(
                            width: 64,
                            child: ListWheelScrollView.useDelegate(
                              controller: periodController,
                              itemExtent: 44,
                              perspective: 0.003,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                HapticFeedback.selectionClick();
                                setSheetState(() => isAM = i == 0);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 2,
                                builder: (context, index) {
                                  final label = index == 0 ? 'AM' : 'PM';
                                  final isSel =
                                      (index == 0) == isAM;
                                  return Center(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: isSel ? 18 : 15,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSel
                                            ? AppColors.primary
                                            : AppColors.textSecondary
                                                .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Confirm button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          int hour24 = selectedHour % 12;
                          if (!isAM) hour24 += 12;
                          Navigator.pop(context,
                              TimeOfDay(hour: hour24, minute: selectedMinute));
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _showDateSheet(BuildContext ctx, DateTime initial) {
    DateTime selectedDate = initial;

    return showModalBottomSheet<DateTime>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_today_rounded,
                            size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pick a date',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Calendar
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: AppColors.textPrimary,
                        ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    onDateChanged: (picked) {
                      HapticFeedback.selectionClick();
                      setSheetState(() => selectedDate = picked);
                    },
                  ),
                ),
                // Confirm button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, selectedDate);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Save / delete ───

  Future<void> _save() async {
    if (_isSaving || !_isValid) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (_isEditing && widget.existingEvent!.notificationId != null) {
        await NotificationService.instance
            .cancelReminder(widget.existingEvent!.notificationId);
      }

      final event = CalendarEvent(
        id: _isEditing ? widget.existingEvent!.id : IdGenerator.generate(),
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        date: _date,
        startTime: _isAllDay ? null : _startTime,
        endTime: _isAllDay ? null : _endTime,
        isAllDay: _isAllDay,
        category: _category,
        reminderMinutesBefore: _reminder.minutes,
        createdAt:
            _isEditing ? widget.existingEvent!.createdAt : DateTime.now(),
      );

      int? notificationId;
      if (_reminder != ReminderOption.none) {
        notificationId =
            await NotificationService.instance.scheduleReminder(event);
      }

      final eventWithNotification =
          event.copyWith(notificationId: notificationId);
      await eventRepository.saveEvent(eventWithNotification);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Couldn\'t save. Try again?'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await NotificationService.instance
          .cancelReminder(widget.existingEvent!.notificationId);
      await eventRepository.deleteEvent(widget.existingEvent!.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceTint,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: 100 + MediaQuery.of(context).padding.bottom,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(theme),
                    const SizedBox(height: 16),
                    // Main journaling card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildJournalCard(theme),
                    ),
                    const SizedBox(height: 16),
                    // When & where (inline tappable sentence)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildWhenCard(theme),
                    ),
                    const SizedBox(height: 16),
                    // Color & vibe (category as colored circles)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildCategoryRow(theme),
                    ),
                    const SizedBox(height: 16),
                    // Remind me
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildReminderRow(theme),
                    ),
                    // Delete
                    if (_isEditing) ...[
                      const SizedBox(height: 32),
                      Center(
                        child: GestureDetector(
                          onTap: _deleteEvent,
                          child: Text(
                            'Delete this event',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.error.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Floating save button
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: _buildSaveButton(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 22,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Edit Event' : 'New Event',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
              maxLength: AppConstants.maxEventTitleLength,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What\'s happening?',
                hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.18),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                isDense: true,
              ),
            ),
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                height: 1,
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
            ),
            // Notes
            TextField(
              controller: _notesController,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.6,
              ),
              maxLength: AppConstants.maxEventNotesLength,
              maxLines: null,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Any details or notes...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhenCard(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Date row
              _buildWhenRow(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                child: Expanded(
                  child: _buildTappableChip(
                    label: _formatDateCasually(_date),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                ),
              ),
              if (!_isAllDay) ...[
                const SizedBox(height: 12),
                // Time row
                _buildWhenRow(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  child: Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTappableChip(
                            label: _startTime != null
                                ? _formatTime(_startTime!)
                                : 'Start',
                            icon: Icons.access_time_rounded,
                            onTap: _pickStartTime,
                            isPlaceholder: _startTime == null,
                          ),
                        ),
                        if (_startTime != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '–',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildTappableChip(
                              label: _endTime != null
                                  ? _formatTime(_endTime!)
                                  : 'End',
                              icon: Icons.access_time_rounded,
                              onTap: _pickEndTime,
                              isPlaceholder: _endTime == null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // All day toggle row
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isAllDay = !_isAllDay);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isAllDay
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isAllDay
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        size: 16,
                        color: _isAllDay
                            ? AppColors.primary
                            : AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'All day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              _isAllDay ? FontWeight.w600 : FontWeight.w500,
                          color: _isAllDay
                              ? AppColors.primary
                              : AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhenRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildTappableChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPlaceholder
              ? AppColors.surfaceTint
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isPlaceholder
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPlaceholder
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: EventCategory.values.map((cat) {
                final isSelected = _category == cat;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _category = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cat.color.withValues(alpha: 0.12)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 32 : 24,
                          height: isSelected ? 32 : 24,
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          cat.color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? cat.color
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderRow(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text(
                  'Remind me',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReminderOption.values.map((opt) {
                final isSelected = _reminder == opt;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _reminder = opt);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      opt.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary
                                .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : _save,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isValid
                  ? [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.85)
                    ]
                  : [
                      theme.colorScheme.surfaceContainerHighest,
                      theme.colorScheme.surfaceContainerHighest,
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isValid
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: _isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isEditing ? 'Save' : 'Save Event',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _isValid
                          ? Colors.white
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
