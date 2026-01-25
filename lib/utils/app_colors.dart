import 'package:flutter/material.dart';

/// Centralized color definitions for the entire app
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ============ Cat Mascot Theme Colors ============
  static const catOrange = Color(0xFFFF8C42);
  static const catOrangeLight = Color(0xFFFFE4D1);
  static const catCream = Color(0xFFFFF8F0);
  static const catBlue = Color(0xFF5B9BD5);
  static const catGold = Color(0xFFFFB84D);

  // ============ Text Colors ============
  static const textPrimary = Color(0xFF2C2C2C);
  static const textSecondary = Color(0xFF666666);
  static const textOnDark = Colors.white;

  // ============ Semantic Colors ============
  static const error = Color(0xFFE57373);
  static const success = Color(0xFF58CC02);
  static const warning = Color(0xFFFF9600);

  // ============ Emotion/Mood Colors (Duolingo-inspired) ============
  static const emotionHappy = Color(0xFF58CC02);
  static const emotionNeutral = Color(0xFF1CB0F6);
  static const emotionWorried = Color(0xFFFF9600);
  static const emotionSad = Color(0xFFFF4B4B);
  static const emotionCelebrate = Color(0xFFFFD700);

  // ============ Background Colors ============
  static const surfaceLight = Color(0xFFF7F7F7);
  static const surfaceWhite = Colors.white;

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
