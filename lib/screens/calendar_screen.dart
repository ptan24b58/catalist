import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../domain/event.dart';
import '../domain/goal.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../utils/app_colors.dart';
import '../utils/date_utils.dart' as app_date;
import '../widgets/dot_lottie_asset.dart';
import 'add_edit_event_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  late DateTime _selectedDate;
  Map<DateTime, List<CalendarEvent>> _monthEvents = {};
  List<CalendarEvent> _selectedDayEvents = [];
  Set<DateTime> _perfectDays = {};
  List<Goal> _dailyGoals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final monthEvents =
        await eventRepository.getEventsForMonth(_focusedMonth);
    final dayEvents = await eventRepository.getEventsForDate(_selectedDate);
    final perfectDays = await goalRepository.getPerfectDaysHistory();
    final dailyGoals = await goalRepository.getDailyGoals();
    if (!mounted) return;
    setState(() {
      _monthEvents = monthEvents;
      _selectedDayEvents = dayEvents;
      _perfectDays = perfectDays;
      _dailyGoals = dailyGoals;
      _isLoading = false;
    });
  }

  void _goToPreviousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
    _loadEvents();
  }

  void _goToNextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
    _loadEvents();
  }

  void _goToToday() {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    _loadEvents();
  }

  void _selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() => _selectedDate = date);
    _loadDayEvents();
  }

  Future<void> _loadDayEvents() async {
    final dayEvents = await eventRepository.getEventsForDate(_selectedDate);
    if (!mounted) return;
    setState(() => _selectedDayEvents = dayEvents);
  }

  Future<void> _navigateToAddEvent() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(initialDate: _selectedDate),
      ),
    );
    if (result == true) _loadEvents();
  }

  Future<void> _navigateToEditEvent(CalendarEvent event) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(existingEvent: event),
      ),
    );
    if (result == true) _loadEvents();
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event'),
        content: Text('Delete "${event.title}"?'),
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
      await NotificationService.instance.cancelReminder(event.notificationId);
      await eventRepository.deleteEvent(event.id);
      _loadEvents();
    }
  }

  String _selectedDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate == today) return 'Today';
    if (_selectedDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    }
    if (_selectedDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMM d').format(_selectedDate);
  }

  int get _totalEventsThisMonth {
    int count = 0;
    for (final list in _monthEvents.values) {
      count += list.length;
    }
    return count;
  }

  /// Check if all daily goals were completed on a specific date (perfect day)
  bool _isPerfectDay(DateTime date) {
    final normalizedDate = app_date.DateUtils.normalizeToDay(date);
    
    // Check persisted history first
    if (_perfectDays.contains(normalizedDate)) {
      return true;
    }
    
    // Also check current daily goals status (for today that may not be saved yet)
    if (_dailyGoals.isEmpty) return false;
    
    return _dailyGoals.every((goal) {
      if (goal.lastCompletedAt == null) return false;
      final completedDate = app_date.DateUtils.normalizeToDay(goal.lastCompletedAt!);
      return completedDate == normalizedDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceTint,
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab',
        onPressed: _navigateToAddEvent,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.calendar_today_rounded),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(child: _buildHeader()),
                  // Calendar card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildCalendarCard(),
                    ),
                  ),
                  // Day header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: _buildSelectedDayHeader(),
                    ),
                  ),
                  // Events or empty state
                  if (_selectedDayEvents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _AnimatedEventCard(
                            event: _selectedDayEvents[index],
                            index: index,
                            onTap: () => _navigateToEditEvent(
                                _selectedDayEvents[index]),
                            onDelete: () =>
                                _deleteEvent(_selectedDayEvents[index]),
                          ),
                          childCount: _selectedDayEvents.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_totalEventsThisMonth > 0)
                  Text(
                    '$_totalEventsThisMonth event${_totalEventsThisMonth == 1 ? '' : 's'} this month',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
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
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            _buildMonthHeader(),
            const SizedBox(height: 16),
            _buildWeekdayRow(),
            const SizedBox(height: 4),
            _buildCalendarGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goToPreviousMonth,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  size: 22, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _goToToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _goToNextMonth,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  size: 22, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: List.generate(7, (col) {
                final index = row * 7 + col;
                if (index < startWeekday ||
                    index >= startWeekday + daysInMonth) {
                  return const Expanded(child: SizedBox(height: 48));
                }

                final day = index - startWeekday + 1;
                final date = DateTime(year, month, day);
                final isToday = date == today;
                final isSelected = date == _selectedDate;
                final dateKey = DateTime(year, month, day);
                final dayEvents = _monthEvents[dateKey] ?? [];
                final isPast = date.isBefore(today);

                final isPerfectDay = _isPerfectDay(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 48,
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : isToday
                                ? AppColors.primary.withValues(alpha: 0.04)
                                : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Fire icon behind date number (perfect day)
                              if (isPerfectDay)
                                Transform.translate(
                                  offset: const Offset(0, -3),
                                  child: Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 32,
                                    color: Colors.deepOrange.withOpacity(0.5),
                                  ),
                                ),
                              // Date number container
                              Container(
                                width: 30,
                                height: 30,
                                decoration: isToday
                                    ? BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.primary,
                                            AppColors.primary
                                                .withValues(alpha: 0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      )
                                    : null,
                                alignment: Alignment.center,
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isToday
                                        ? Colors.white
                                        : isSelected
                                            ? AppColors.primary
                                            : isPast
                                                ? AppColors.textSecondary
                                                    .withValues(alpha: 0.5)
                                                : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 6,
                            child: dayEvents.isNotEmpty
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: dayEvents
                                        .take(3)
                                        .map((e) => Container(
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.symmetric(
                                                  horizontal: 1),
                                              decoration: BoxDecoration(
                                                color: e.category.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ))
                                        .toList(),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedDayHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _selectedDateLabel(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (_selectedDayEvents.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_selectedDayEvents.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: DotLottieAsset(
                'assets/idle/mascot.lottie',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing planned',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'tap + to add something',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedEventCard extends StatefulWidget {
  final CalendarEvent event;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AnimatedEventCard({
    required this.event,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_AnimatedEventCard> createState() => _AnimatedEventCardState();
}

class _AnimatedEventCardState extends State<_AnimatedEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _timeRangeText() {
    if (widget.event.isAllDay) return 'All day';
    if (widget.event.startTime == null) return '';
    final start = _formatTime(widget.event.startTime!);
    if (widget.event.endTime == null) return start;
    return '$start – ${_formatTime(widget.event.endTime!)}';
  }

  @override
  Widget build(BuildContext context) {
    final catColor = widget.event.category.color;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: ValueKey(widget.event.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            widget.onDelete();
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_rounded,
                color: AppColors.error, size: 22),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Colored left strip
                      Container(width: 4, color: catColor),
                      // Time badge
                      if (_timeRangeText().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.event.isAllDay)
                                Icon(Icons.wb_sunny_rounded,
                                    size: 18,
                                    color: catColor.withValues(alpha: 0.7))
                              else if (widget.event.startTime != null) ...[
                                Text(
                                  _formatTime(widget.event.startTime!)
                                      .split(' ')[0],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: catColor,
                                  ),
                                ),
                                Text(
                                  _formatTime(widget.event.startTime!)
                                      .split(' ')[1],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: catColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      // Subtle vertical divider
                      if (_timeRangeText().isNotEmpty)
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          color: AppColors.textSecondary.withValues(alpha: 0.08),
                        ),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 16, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.event.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.event.category.displayName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: catColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.event.endTime != null &&
                                  !widget.event.isAllDay) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'until ${_formatTime(widget.event.endTime!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                              if (widget.event.notes != null &&
                                  widget.event.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  widget.event.notes!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.7),
                                    height: 1.4,
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
            ),
          ),
        ),
      ),
    );
  }
}
