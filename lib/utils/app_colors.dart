import 'package:flutter/material.dart';

/// Centralized color definitions for the entire app
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ============ Primary Palette (Ocean / Baby Blue) ============
  /// Light purple – main primary (replaces #0284C7)
  static const primary = Color(0xFFA78BFA);
  /// Baby blue – light primary, backgrounds, tracks
  static const primaryLight = Color(0xFFBAE6FD);
  /// Soft blue-white – scaffold/surface tint
  static const surfaceTint = Color(0xFFF0F9FF);
  /// Medium blue – accents, links
  static const catBlue = Color(0xFF0EA5E9);
  static const catGold = Color(0xFFFFB84D);
  // Legacy aliases so existing UI uses new primary palette
  static const catOrange = primary;
  static const catOrangeLight = primaryLight;
  static const catCream = surfaceTint;

  // ============ Text Colors ============
  static const textPrimary = Color(0xFF2C2C2C);
  static const textSecondary = Color(0xFF666666);
  static const textOnDark = Colors.white;

  // ============ Semantic Colors ============
  static const error = Color(0xFFE57373);
  /// Softer teal – fits purple/blue without standing out.
  static const success = Color(0xFF2DD4BF);
  static const warning = Color(0xFFFF9600);

  // ============ Emotion/Mood Colors ============
  static const emotionHappy = Color(0xFF2DD4BF);
  static const emotionNeutral = Color(0xFF1CB0F6);
  static const emotionWorried = Color(0xFFFF9600);
  static const emotionSad = Color(0xFFFF4B4B);
  static const emotionCelebrate = Color(0xFFFFD700);

  // ============ Background Colors ============
  static const surfaceLight = Color(0xFFF7F7F7);
  static const surfaceWhite = Colors.white;

  // ============ Gamification Colors (Duolingo-inspired) ============
  /// Streak flame/emoji – always orange (unchanged by primary palette)
  static const streakFlameOrange = Color(0xFFFF8C42);
  // Streak tier colors (warm orange → gold)
  static const streakBronze = Color(0xFFFF8C42);      // 1-6 days
  static const streakSilver = Color(0xFFFF6B35);      // 7-13 days
  static const streakGold = Color(0xFFFF4500);        // 14-29 days
  static const streakPlatinum = Color(0xFFFFD700);    // 30+ days

  // Crown colors
  static const crownGold = Color(0xFFFFD700);
  static const crownGoldDark = Color(0xFFDAA520);
  static const crownShine = Color(0xFFFFF8DC);

  // XP / progress – 2DD4BF accent, CCFBF1 background
  static const xpGreen = Color(0xFF2DD4BF);
  static const xpGreenLight = Color(0xFF2DD4BF);
  static const xpBackground = Color(0xFFCCFBF1);
  /// Classic Duolingo-style green if you prefer it later
  static const xpGreenLegacy = Color(0xFF58CC02);

  // Level badge colors
  static const levelBadgeGold = Color(0xFFFFB800);
  static const levelBadgeBorder = Color(0xFFDAA520);

  // Glow effects
  static const streakGlow = Color(0xFFFF6B35);
  static const crownGlow = Color(0xFFFFD700);

  /// Get emotion color based on emotion type
  static Color getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return emotionHappy;
      case 'neutral':
        return emotionNeutral;
      case 'worried':
        return emotionWorried;
      case 'sad':
        return emotionSad;
      case 'celebrate':
        return emotionCelebrate;
      default:
        return emotionNeutral;
    }
  }
}
