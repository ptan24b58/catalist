import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/goal_image_service.dart';
import '../utils/app_colors.dart';
import 'goals_list_screen.dart';
import 'memories_screen.dart';
import 'memory_capture_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _imageService = GoalImageService();

  final List<Widget> _screens = const [
    GoalsListScreen(),
    MemoriesScreen(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _onCameraPressed() async {
    HapticFeedback.mediumImpact();
    
    // Directly open camera for quick capture
    final image = await _imageService.pickFromCamera();
    if (image != null && mounted) {
      // Navigate to memory capture with the taken photo
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => MemoryCaptureScreen(
            initialImage: image,
          ),
        ),
      );
      
      // If memory was saved, switch to memories tab
      if (result == true && mounted) {
        setState(() => _currentIndex = 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Goals tab
                Expanded(
                  child: _buildNavItem(
                    index: 0,
                    icon: Icons.flag_rounded,
                    label: 'Goals',
                  ),
                ),
                // Center camera button
                _buildCameraButton(),
                // Memories tab
                Expanded(
                  child: _buildNavItem(
                    index: 1,
                    icon: Icons.photo_album_rounded,
                    label: 'Memories',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: _onCameraPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color(0xFFFF8A65), // Warm accent
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
