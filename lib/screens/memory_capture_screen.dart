import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../domain/goal.dart';
import '../domain/memory.dart';
import '../services/goal_image_service.dart';
import '../services/service_locator.dart';
import '../utils/app_colors.dart';
import '../utils/id_generator.dart';
import '../utils/logger.dart';

/// Screen for capturing/editing a memory - designed to feel like journaling, not a form.
///
/// Three modes via constructor params:
/// - **Goal completion** (`goal != null`): Congratulations header, creates memory linked to goal
/// - **Standalone** (`goal == null, existingMemory == null`): Photo-first, story-style capture
/// - **Edit** (`existingMemory != null`): Pre-fills all fields, replaces image on save
class MemoryCaptureScreen extends StatefulWidget {
  final Goal? goal;
  final Memory? existingMemory;

  const MemoryCaptureScreen({super.key, this.goal, this.existingMemory});

  @override
  State<MemoryCaptureScreen> createState() => _MemoryCaptureScreenState();
}

class _MemoryCaptureScreenState extends State<MemoryCaptureScreen>
    with SingleTickerProviderStateMixin {
  final _memoController = TextEditingController();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _memoFocusNode = FocusNode();
  final _imageService = GoalImageService();
  File? _selectedImage;
  String? _existingImagePath;
  DateTime _eventDate = DateTime.now();
  bool _isSaving = false;
  bool _showCalendar = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get _isGoalCompletion => widget.goal != null;
  bool get _isEditing => widget.existingMemory != null;
  bool get _isStandalone => !_isGoalCompletion && !_isEditing;
  bool get _hasPhoto =>
      _selectedImage != null ||
      (_existingImagePath != null && File(_existingImagePath!).existsSync());

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (_isEditing) {
      final m = widget.existingMemory!;
      _titleController.text = m.title;
      _memoController.text = m.memo ?? '';
      _existingImagePath = m.imagePath;
      _eventDate = m.eventDate;
    } else if (_isGoalCompletion) {
      _titleController.text = widget.goal!.title;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _memoController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  String _formatDateCasually(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    if (date.year == now.year) return DateFormat('MMM d').format(date);
    return DateFormat('MMM d, yyyy').format(date);
  }

  void _toggleCalendar() {
    HapticFeedback.selectionClick();
    setState(() => _showCalendar = !_showCalendar);
  }

  Future<void> _pickFromCamera() async {
    final image = await _imageService.pickFromCamera();
    if (image != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedImage = image;
        _existingImagePath = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _imageService.pickFromGallery();
    if (image != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedImage = image;
        _existingImagePath = null;
      });
    }
  }

  void _showImageSourcePicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ImageSourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickFromCamera();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ImageSourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickFromGallery();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      _titleFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Give this memory a name'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      String? imagePath = _existingImagePath;

      if (_selectedImage != null) {
        final entityId = _isEditing
            ? widget.existingMemory!.id
            : (_isGoalCompletion ? widget.goal!.id : IdGenerator.generate());
        imagePath = await _imageService.saveImage(entityId, _selectedImage!);
      }

      final memo = _memoController.text.trim().isNotEmpty
          ? _memoController.text.trim()
          : null;

      if (_isEditing) {
        final updated = widget.existingMemory!.copyWith(
          title: title,
          memo: memo,
          imagePath: imagePath,
          eventDate: _eventDate,
        );
        await memoryRepository.saveMemory(updated);
      } else {
        final memory = Memory(
          id: IdGenerator.generate(),
          title: title,
          memo: memo,
          imagePath: imagePath,
          createdAt: DateTime.now(),
          eventDate: _isGoalCompletion
              ? (widget.goal!.lastCompletedAt ?? DateTime.now())
              : _eventDate,
          linkedGoalId: _isGoalCompletion ? widget.goal!.id : null,
          linkedGoalTitle: _isGoalCompletion ? widget.goal!.title : null,
        );
        await memoryRepository.saveMemory(memory);

        if (_isGoalCompletion) {
          final updatedGoal = widget.goal!.copyWith(
            completionImagePath: imagePath,
            completionMemo: memo,
          );
          await goalRepository.saveGoal(updatedGoal);
        }
      }

      if (!mounted) return;

      if (_isGoalCompletion) {
        Navigator.of(context).pop({'celebrate': true, 'xp': 20});
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to save memory', e, stackTrace);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Couldn\'t save. Try again?'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _skipAndCelebrate() async {
    if (!mounted) return;
    Navigator.of(context).pop({'celebrate': true, 'xp': 20});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceTint,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: 100 + MediaQuery.of(context).padding.bottom,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    _buildTopBar(theme),

                    // Goal completion badge
                    if (_isGoalCompletion) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: _buildCompletionBadge(theme),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Photo area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildPhotoArea(theme),
                    ),

                    const SizedBox(height: 20),

                    // Journal card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildJournalCard(theme),
                    ),
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
          // Close button
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
          // Screen title
          Expanded(
            child: Text(
              _isGoalCompletion
                  ? 'Capture this moment'
                  : _isEditing
                      ? 'Edit memory'
                      : 'New memory',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (_isGoalCompletion)
            TextButton(
              onPressed: _isSaving ? null : _skipAndCelebrate,
              child: Text(
                'Skip',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletionBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.xpGreen.withValues(alpha: 0.15),
            AppColors.xpGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.xpGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            size: 20,
            color: AppColors.xpGreen,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Goal completed! Save a memory of this moment.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoArea(ThemeData theme) {
    Widget? imageWidget;
    if (_selectedImage != null) {
      imageWidget = Image.file(_selectedImage!, fit: BoxFit.cover);
    } else if (_existingImagePath != null &&
        File(_existingImagePath!).existsSync()) {
      imageWidget = Image.file(File(_existingImagePath!), fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: _showImageSourcePicker,
      child: Container(
        height: _hasPhoto ? 240 : 160,
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
        clipBehavior: Clip.antiAlias,
        child: imageWidget != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  // Subtle gradient for readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Change photo chip
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Remove photo
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedImage = null;
                          _existingImagePath = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add a photo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'optional',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
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
            // Date chip
            if (_isStandalone || _isEditing) ...[
              _buildDateChip(theme),
              // Inline calendar
              if (_showCalendar) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.8),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: theme.colorScheme.onSurface,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: _eventDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      onDateChanged: (picked) {
                        setState(() {
                          _eventDate = picked;
                          _showCalendar = false;
                        });
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],

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
              maxLength: 100,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isGoalCompletion
                    ? 'How did it feel?'
                    : 'What happened?',
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                isDense: true,
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                height: 1,
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
              ),
            ),

            // Memo
            TextField(
              controller: _memoController,
              focusNode: _memoFocusNode,
              style: TextStyle(
                fontSize: 15,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.6,
              ),
              maxLength: 500,
              maxLines: null,
              minLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isGoalCompletion
                    ? 'Tell the story of this achievement...'
                    : 'Tell the story...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.25),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(ThemeData theme) {
    return GestureDetector(
      onTap: _toggleCalendar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              _formatDateCasually(_eventDate),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _showCalendar ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    final hasContent = _titleController.text.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : _save,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasContent
                    ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)]
                    : [
                        theme.colorScheme.surfaceContainerHighest,
                        theme.colorScheme.surfaceContainerHighest,
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: hasContent
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
                      _isGoalCompletion
                          ? 'Save & Celebrate'
                          : _isEditing
                              ? 'Save'
                              : 'Save Memory',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: hasContent
                            ? Colors.white
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
