import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/gamification.dart';

/// Simple streak badge - minimalist design, no animations
class StreakBadge extends StatelessWidget {
  final int streak;
  final double size;
  final bool showDays;

  const StreakBadge({
    super.key,
    required this.streak,
    this.size = 24,
    this.showDays = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = Gamification.getStreakColor(streak);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department,
          size: size,
          color: streak > 0 ? color : AppColors.textSecondary.withValues(alpha: 0.4),
        ),
        if (showDays) ...[
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: size * 0.7,
              fontWeight: FontWeight.bold,
              color: streak > 0 ? color : AppColors.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ],
    );
  }
}

/// Streak card for detail screens - minimalist
class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final tier = Gamification.getStreakTier(currentStreak);

    return Row(
      children: [
        // Current streak
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_fire_department,
            iconColor: tier.color,
            label: 'Current Streak',
            value: '$currentStreak',
            subtitle: 'days',
            badge: currentStreak > 0 ? tier.name : null,
            badgeColor: tier.color,
          ),
        ),
        const SizedBox(width: 12),
        // Best streak
        Expanded(
          child: _buildStatCard(
            icon: Icons.emoji_events,
            iconColor: AppColors.catGold,
            label: 'Best Streak',
            value: '$bestStreak',
            subtitle: 'days',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor?.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
