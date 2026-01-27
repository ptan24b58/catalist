import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Simple crown icon for completed goals - no animation
class CrownIcon extends StatelessWidget {
  final double size;
  final bool animate; // Kept for API compatibility, ignored

  const CrownIcon({
    super.key,
    this.size = 24,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.workspace_premium,
      size: size,
      color: AppColors.crownGold,
    );
  }
}

/// Crown badge for completed goal cards
class CrownBadge extends StatelessWidget {
  final double size;

  const CrownBadge({
    super.key,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.crownGold,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.crownGold.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.workspace_premium,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }
}
