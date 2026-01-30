import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/goal.dart';
import '../domain/memory.dart';
import '../services/goal_image_service.dart';
import '../services/service_locator.dart';
import '../utils/app_colors.dart';
import '../utils/id_generator.dart';
import '../utils/logger.dart';

/// Screen for capturing/editing a memory.
///
/// Three modes via constructor params:
/// - **Goal completion** (`goal != null`): Congratulations header, creates memory linked to goal
/// - **Standalone** (`goal == null, existingMemory == null`): Title field, optional date picker, photo, memo
/// - **Edit** (`existingMemory != null`): Pre-fills all fields, replaces image on save
class MemoryCaptureScreen extends StatefulWidget {
  final Goal? goal;
  final Memory? existingMemory;

  const MemoryCaptureScreen({super.key, this.goal, this.existingMemory});

  @override
  State<MemoryCaptureScreen> createState() => _MemoryCaptureScreenState();
}

class _MemoryCaptureScreenState extends State<MemoryCaptureScreen> {
  final _memoController = TextEditingController();
  final _titleController = TextEditingController();
  final _imageService = GoalImageService();
  File? _selectedImage;
  String? _existingImagePath;
  DateTime _eventDate = DateTime.now();
  bool _isSaving = false;

  bool get _isGoalCompletion => widget.goal != null;
  bool get _isEditing => widget.existingMemory != null;
  bool get _isStandalone => !_isGoalCompletion && !_isEditing;

  @override
  void initState() {
    super.initState();
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
    _memoController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final image = await _imageService.pickFromCamera();
    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
        _existingImagePath = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _imageService.pickFromGallery();
    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
        _existingImagePath = null;
      });
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Add a Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imagePath = _existingImagePath;

      // Save new image if selected
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
        // Update existing memory
        final updated = widget.existingMemory!.copyWith(
          title: title,
          memo: memo,
          imagePath: imagePath,
          eventDate: _eventDate,
        );
        await memoryRepository.saveMemory(updated);
      } else {
        // Create new memory
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

        // Also update goal with completion data for backward compat
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
          const SnackBar(content: Text('Failed to save. Please try again.')),
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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(
              context, _isGoalCompletion ? false : null),
        ),
        title: Text(
          _isEditing
              ? 'Edit Memory'
              : _isGoalCompletion
                  ? 'Capture This Moment'
                  : 'New Memory',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebration header (goal completion mode only)
              if (_isGoalCompletion) ...[
                _buildCelebrationHeader(theme),
                const SizedBox(height: 32),
              ],

              // Title field (standalone and edit modes)
              if (_isStandalone || _isEditing) ...[
                Text(
                  'Title',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: 'What happened?',
                    hintStyle: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Date picker (standalone and edit modes)
              if (_isStandalone || _isEditing) ...[
                Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMMM d, yyyy').format(_eventDate),
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.edit,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Photo section
              Text(
                'Add a Photo (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isGoalCompletion
                    ? 'Capture this achievement with a memorable photo'
                    : 'Add a photo to remember this moment',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              _buildImagePicker(theme),

              const SizedBox(height: 32),

              // Memo section
              Text(
                'Write a Memo (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isGoalCompletion
                    ? 'Reflect on your journey and what this means to you'
                    : 'Capture your thoughts about this moment',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _memoController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: _isGoalCompletion
                      ? 'How does it feel to achieve this goal?'
                      : 'What made this moment special?',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.xpGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isGoalCompletion
                            ? 'Save & Celebrate'
                            : _isEditing
                                ? 'Save Changes'
                                : 'Save Memory',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),

              if (_isGoalCompletion) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSaving ? null : _skipAndCelebrate,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.xpGreen.withValues(alpha: 0.1),
            AppColors.xpGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.xpGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            size: 48,
            color: AppColors.xpGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'Congratulations!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You completed "${widget.goal!.title}"',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme) {
    final hasImage = _selectedImage != null || _existingImagePath != null;
    final imageWidget = _selectedImage != null
        ? Image.file(_selectedImage!, fit: BoxFit.cover)
        : (_existingImagePath != null && File(_existingImagePath!).existsSync())
            ? Image.file(File(_existingImagePath!), fit: BoxFit.cover)
            : null;

    return GestureDetector(
      onTap: _showImageSourcePicker,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage && imageWidget != null
                ? AppColors.xpGreen
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: hasImage && imageWidget != null ? 2 : 1,
          ),
        ),
        child: hasImage && imageWidget != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imageWidget,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedImage = null;
                        _existingImagePath = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _showImageSourcePicker,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _existingImagePath != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Photo unavailable',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to add a new photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to add a photo',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
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
      color:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
