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
    final flameColor = streak > 0 ? AppColors.streakFlameOrange : AppColors.textSecondary.withValues(alpha: 0.4);
    final textColor = streak > 0 ? Gamification.getStreakColor(streak) : AppColors.textSecondary.withValues(alpha: 0.4);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department,
          size: size,
          color: flameColor,
        ),
        if (showDays) ...[
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: size * 0.7,
              fontWeight: FontWeight.bold,
              color: textColor,
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
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.local_fire_department,
            iconColor: currentStreak > 0 ? AppColors.streakFlameOrange : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            label: 'Current Streak',
            value: '$currentStreak',
            subtitle: 'days',
            badge: currentStreak > 0 ? tier.name : null,
            badgeColor: tier.color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
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

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
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
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
