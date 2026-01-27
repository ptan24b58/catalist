import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Circular level badge with gold border - minimalist design
class LevelBadge extends StatelessWidget {
  final int level;
  final double size;

  const LevelBadge({
    super.key,
    required this.level,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AppColors.levelBadgeGold,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.levelBadgeGold.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
            color: AppColors.levelBadgeBorder,
          ),
        ),
      ),
    );
  }
}

/// Enhanced level banner for goals list screen - minimalist
class LevelBanner extends StatelessWidget {
  final int level;
  final int totalXP;
  final int xpInLevel;
  final double levelProgress;

  const LevelBanner({
    super.key,
    required this.level,
    required this.totalXP,
    required this.xpInLevel,
    required this.levelProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Row(
            children: [
              // Level badge
              LevelBadge(level: level, size: 56),
              const SizedBox(width: 16),
              // Level info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$xpInLevel / 100 XP to next level',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Total XP
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.xpBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$totalXP',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.xpGreen,
                      ),
                    ),
                    const Text(
                      'XP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.xpGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 8,
              backgroundColor: AppColors.catCream,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.xpGreen),
            ),
          ),
        ],
      ),
    );
  }
}
