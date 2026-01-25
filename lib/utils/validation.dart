import 'constants.dart';

/// Input validation utilities
class Validation {
  /// Validate goal title
  static String? validateTitle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter a goal title';
    if (trimmed.length < AppConstants.minTitleLength) {
      return 'Title must be at least ${AppConstants.minTitleLength} character';
    }
    if (trimmed.length > AppConstants.maxTitleLength) {
      return 'Title must be no more than ${AppConstants.maxTitleLength} characters';
    }
    return null;
  }

  /// Validate goal target value
  static String? validateTarget(int? value) {
    if (value == null) return 'Target is required';
    if (value < AppConstants.minTarget) {
      return 'Target must be at least ${AppConstants.minTarget}';
    }
    if (value > AppConstants.maxTarget) {
      return 'Target must be no more than ${AppConstants.maxTarget}';
    }
    return null;
  }

  /// Validate goal ID format
  static bool isValidGoalId(String? id) {
    return id != null &&
        id.isNotEmpty &&
        id.length <= AppConstants.maxIdLength;
  }

  /// Sanitize goal title
  static String sanitizeTitle(String title) => title.trim();
}
